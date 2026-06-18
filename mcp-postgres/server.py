"""
MCP Lab: CRM MCP server (custom, ~90 lines).

PRESENTATION POINT: this whole file is what an "MCP integration" actually is.
Each @mcp.tool function is advertised to the AI client with its name,
docstring, and typed parameters; the client model decides when to call them.
Everything on the wire is JSON-RPC over Streamable HTTP — watch it live in
mitmproxy at http://localhost:8081.

Defense in depth, three layers:
  1. This server only exposes read-style tools (no insert/update/delete tools).
  2. run_query() rejects anything that isn't a single SELECT/WITH statement.
  3. Even if both of the above failed, the DB credential (mcp_reader) is a
     SELECT-only role — enforced by Postgres itself.
"""

import os
import re

import psycopg
from fastmcp import FastMCP

DSN = os.environ.get(
    "DATABASE_URL",
    "postgresql://mcp_reader:readonly-lab@postgres:5432/crm",
)

mcp = FastMCP("crm-database")


def _query(sql: str, params: tuple = ()) -> str:
    """Run a query and return results as a markdown-ish table string."""
    with psycopg.connect(DSN, connect_timeout=5) as conn:
        conn.read_only = True  # session-level guard, layer 2.5
        with conn.cursor() as cur:
            cur.execute(sql, params)
            if cur.description is None:
                return "(no result set)"
            cols = [d.name for d in cur.description]
            rows = cur.fetchmany(200)  # cap output: don't flood the model's context
    lines = [" | ".join(cols), " | ".join("---" for _ in cols)]
    lines += [" | ".join("" if v is None else str(v) for v in row) for row in rows]
    if len(rows) == 200:
        lines.append("... (truncated at 200 rows)")
    return "\n".join(lines)


@mcp.tool
def list_tables() -> str:
    """List all tables in the CRM database with their row counts."""
    return _query(
        """
        SELECT relname AS table_name, n_live_tup AS approx_rows
        FROM pg_stat_user_tables
        ORDER BY relname
        """
    )


@mcp.tool
def describe_table(table_name: str) -> str:
    """Show the columns and data types of a CRM table."""
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", table_name):
        return "Error: invalid table name."
    return _query(
        """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        ORDER BY ordinal_position
        """,
        (table_name,),
    )


@mcp.tool
def find_customer(name_fragment: str) -> str:
    """Search customers by (partial) company name. Returns company details,
    contacts, and a summary of their orders and open support tickets."""
    like = f"%{name_fragment}%"
    out = ["## Matching customers", _query(
        "SELECT id, company_name, industry, city, province, account_tier, created_at, ssn "
        "FROM customers WHERE company_name ILIKE %s", (like,))]
    out += ["\n## Contacts", _query(
        "SELECT c.full_name, c.title, c.email, c.phone, cu.company_name "
        "FROM contacts c JOIN customers cu ON cu.id = c.customer_id "
        "WHERE cu.company_name ILIKE %s", (like,))]
    out += ["\n## Orders", _query(
        "SELECT o.order_ref, o.description, o.amount_cad, o.status, o.order_date "
        "FROM orders o JOIN customers cu ON cu.id = o.customer_id "
        "WHERE cu.company_name ILIKE %s ORDER BY o.order_date DESC", (like,))]
    out += ["\n## Support tickets", _query(
        "SELECT t.subject, t.severity, t.status, t.opened_at, t.summary "
        "FROM support_tickets t JOIN customers cu ON cu.id = t.customer_id "
        "WHERE cu.company_name ILIKE %s ORDER BY t.opened_at DESC", (like,))]
    return "\n".join(out)


@mcp.tool
def run_query(sql: str) -> str:
    """Run a read-only SQL query (single SELECT or WITH statement) against
    the CRM database. Tables: customers, contacts, orders, support_tickets."""
    cleaned = sql.strip().rstrip(";")
    if ";" in cleaned:
        return "Error: only a single statement is allowed."
    if not re.match(r"^(select|with)\b", cleaned, re.IGNORECASE):
        return "Error: only SELECT/WITH queries are allowed."
    try:
        return _query(cleaned)
    except psycopg.Error as e:
        # The DB role is SELECT-only, so even a clever bypass of the regex
        # above dies here. Surface that honestly to the model.
        return f"Database refused the query: {e}"


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
