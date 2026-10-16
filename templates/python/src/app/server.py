# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Lightweight local web server adhering to localhost binding, W3C CSP, launch token auth, and browser automation."""

import os
import secrets
import sys
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


def format_clickable_url(url: str, text: Optional[str] = None, stream=sys.stderr) -> str:
    """Format a URL as an OSC 8 clickable terminal hyperlink with plain-text fallback.

    Args:
        url: Absolute URI target.
        text: Optional link anchor text. Defaults to the URL string.
        stream: Output stream to inspect for interactive TTY attachment.

    Returns:
        OSC 8 formatted ANSI escape string if TTY and color-enabled, or plain URL string.
    """
    display = text or url
    if "NO_COLOR" in os.environ or not (hasattr(stream, "isatty") and stream.isatty()):
        return display if text is None else f"{display} ({url})"
    # Terminal OSC 8 escape sequence: \033]8;;<URL>\033\\<TEXT>\033]8;;\033\\
    return f"\033]8;;{url}\033\\{display}\033]8;;\033\\"


def open_browser(url: str, no_browser: bool = False) -> bool:
    """Open a URL in the user's default browser unless suppressed or running headless.

    Args:
        url: Absolute URL to navigate to.
        no_browser: Whether automatic browser launching is suppressed.

    Returns:
        True if browser launch was initiated, False otherwise.
    """
    if no_browser or os.getenv("CI") == "true":
        return False
    # Suppress browser launch on headless Linux environments lacking a display server
    if sys.platform.startswith("linux") and not (os.getenv("DISPLAY") or os.getenv("WAYLAND_DISPLAY")):
        return False
    try:
        import webbrowser
        return webbrowser.open(url, new=2, autoraise=True)
    except Exception as exc:
        # Non-fatal diagnostic warning; server execution continues unaffected
        sys.stderr.write(f"[mytool] Notice: Could not launch browser automatically: {exc}\n")
        return False


def run_local_server(port: int = 8080, host: str = "127.0.0.1", no_browser: bool = False) -> None:
    """Run the local uvicorn server strictly bound to localhost.

    Args:
        port: TCP port number to listen on. Defaults to 8080.
        host: IP interface to bind to. Defaults strictly to '127.0.0.1'.
        no_browser: Suppress automatic opening of default web browser on launch.
    """
    import uvicorn
    token = secrets.token_hex(32)
    app = create_app(auth_token=token)

    launch_url = f"http://{host}:{port}/?token={token}"
    clickable_url = format_clickable_url(launch_url, stream=sys.stderr)

    # Print authenticated launch URL to stderr (leaving stdout clean for composability)
    sys.stderr.write(f"\n[mytool] Local server running at: {clickable_url}\n")
    sys.stderr.write("[mytool] Bound strictly to localhost for privacy and security. Press Ctrl+C to exit.\n\n")
    sys.stderr.flush()

    # Automatically launch browser window unless suppressed or running in headless mode
    open_browser(launch_url, no_browser=no_browser)

    uvicorn.run(app, host=host, port=port, log_level="warning")
