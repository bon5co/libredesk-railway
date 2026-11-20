# libredesk-railway

Wrapper image for [Libredesk](https://github.com/abhinavxd/libredesk) (open source customer support desk, AGPL-3.0) on Railway.

It runs the official `libredesk/libredesk` image, pinned by digest, and before the server starts it installs the database schema and
the `System` login from `LIBREDESK_SYSTEM_USER_PASSWORD` (no stranger can claim the first account), applies upgrades, and binds to
Railway's injected `PORT`. Once the server answers it sets the app's public URL (`app.root_url`, which otherwise stays
`http://localhost:9000` in invite links and notification mails) to the Railway domain, only while it still holds the default.

Needs Postgres and Redis alongside it; the Railway template wires both. Licence of this wrapper: MIT. Libredesk itself is AGPL-3.0.
