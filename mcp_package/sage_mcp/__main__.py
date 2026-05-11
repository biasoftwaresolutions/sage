"""Entry point: python -m sage_mcp"""
from sage_mcp.server import mcp

if __name__ == "__main__":
    mcp.run(transport="stdio")
