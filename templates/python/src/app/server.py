# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Lightweight local web server adhering to localhost binding, W3C CSP, and launch token auth."""

import secrets
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, Depends, HTTPException, Header, Query, Request, Response, status
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.base import BaseHTTPMiddleware
from app.config import ToolPreset, load_preset, save_preset


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Enforce W3C Content Security Policy and modern defense-in-depth browser headers."""

    async def dispatch(self, request: Request, call_next):
        """Inject strict security headers into every outbound HTTP response.

        Args:
            request: Inbound Starlette Request object.
            call_next: Request handler callback.

        Returns:
            Starlette Response object with hardened security headers attached.
        """
        response = await call_next(request)
        # SECURITY: Restrict resource loading strictly to origin; disallow framing and MIME sniffing
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; script-src 'self' 'unsafe-inline'; "
            "style-src 'self' 'unsafe-inline'; img-src 'self' data:; "
            "object-src 'none'; frame-ancestors 'none';"
        )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response


def create_app(auth_token: Optional[str] = None) -> FastAPI:
    """Create an authenticated, hardened local FastAPI application instance.

    Args:
        auth_token: Optional pre-shared 256-bit hexadecimal launch token.
            If omitted, a cryptographically secure token is automatically generated.

    Returns:
        Configured FastAPI application instance.
    """
    app = FastAPI(
        title="mytool Local Server",
        description="Localhost-bound web server for mytool",
        docs_url=None,  # SECURITY: Disable public swagger docs by default for local privacy
        redoc_url=None,
    )
    app.add_middleware(SecurityHeadersMiddleware)

    # Ephemeral token generated on launch
    server_token = auth_token or secrets.token_hex(32)
    app.state.auth_token = server_token

    def verify_auth(
        request: Request,
        token_query: Optional[str] = Query(None, alias="token"),
        authorization: Optional[str] = Header(None),
    ) -> str:
        """Verify the ephemeral launch token via query param, header, or session cookie.

        Args:
            request: Inbound HTTP request.
            token_query: Optional launch token passed via URL query parameter.
            authorization: Optional HTTP Authorization header (Bearer token).

        Returns:
            Validated token string.

        Raises:
            HTTPException: 401 Unauthorized if the token is missing or invalid.
        """
        cookie_token = request.cookies.get("mytool_session")
        bearer_token = None
        if authorization and authorization.startswith("Bearer "):
            bearer_token = authorization.split(" ")[1]

        candidate = token_query or bearer_token or cookie_token
        # SECURITY: Constant-time digest comparison prevents timing oracle side-channel attacks
        if not candidate or not secrets.compare_digest(candidate, app.state.auth_token):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unauthorized: Valid ephemeral launch token required."
            )
        return candidate

    @app.get("/", response_class=HTMLResponse)
    async def index(request: Request, response: Response, token: Optional[str] = Query(None)):
        """Serve the local single-page web interface upon successful authentication."""
        # Validate launch token and set SameSite=Strict cookie
        if token and secrets.compare_digest(token, app.state.auth_token):
            response.set_cookie(
                key="mytool_session",
                value=token,
                httponly=True,
                samesite="strict",
                secure=False  # Allow http on localhost
            )
        else:
            cookie_token = request.cookies.get("mytool_session")
            if not cookie_token or not secrets.compare_digest(cookie_token, app.state.auth_token):
                return HTMLResponse(
                    "<h3>401 Unauthorized</h3><p>Please open the authenticated link printed in your terminal.</p>",
                    status_code=401
                )

        html_path = Path(__file__).parent / "web" / "index.html"
        return HTMLResponse(content=html_path.read_text(encoding="utf-8"))

    @app.get("/api/preset", response_model=ToolPreset)
    async def get_active_preset(auth: str = Depends(verify_auth)):
        """Retrieve the currently active configuration preset."""
        return load_preset("default")

    @app.post("/api/preset")
    async def update_preset(preset: ToolPreset, auth: str = Depends(verify_auth)):
        """Update and persist configuration preset values to disk."""
        try:
            path = save_preset(preset)
            return {"status": "ok", "path": str(path)}
        except Exception as exc:
            raise HTTPException(status_code=400, detail=str(exc))

    return app


def run_local_server(port: int = 8080, host: str = "127.0.0.1") -> None:
    """Run the local uvicorn server strictly bound to localhost.

    Args:
        port: TCP port number to listen on. Defaults to 8080.
        host: IP interface to bind to. Defaults strictly to '127.0.0.1'.
    """
    import uvicorn
    token = secrets.token_hex(32)
    app = create_app(auth_token=token)

    # Print authenticated launch URL to stderr (leaving stdout clean for composability)
    import sys
    sys.stderr.write(f"\n[mytool] Local server running at: http://{host}:{port}/?token={token}\n")
    sys.stderr.write("[mytool] Bound strictly to localhost for privacy and security. Press Ctrl+C to exit.\n\n")
    sys.stderr.flush()

    uvicorn.run(app, host=host, port=port, log_level="warning")
