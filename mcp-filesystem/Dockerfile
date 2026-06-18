# The official reference filesystem MCP server speaks stdio (it's designed
# to be spawned as a child process by a desktop client). To make it live in
# a container on our dmz network like a real enterprise service, we wrap it
# with supergateway, which bridges stdio <-> Streamable HTTP.
#
# PRESENTATION POINT: this stdio-vs-HTTP split is a real architectural fault
# line in MCP. stdio = local child process, inherits your user's privileges,
# invisible to the network. HTTP = a network service you can segment,
# firewall, proxy, and audit. Enterprises will push toward HTTP for exactly
# the reasons this lab demonstrates.
#
# Built locally on your M4 => arm64 by definition (node base image is multi-arch).
FROM node:22-slim

RUN npm install -g supergateway @modelcontextprotocol/server-filesystem

EXPOSE 8000
ENTRYPOINT ["supergateway", \
    "--stdio", "mcp-server-filesystem /data", \
    "--outputTransport", "streamableHttp", \
    "--port", "8000", \
    "--streamableHttpPath", "/mcp"]
