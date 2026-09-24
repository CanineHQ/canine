"""Canine's computer-use server for agent computers (Linux/X11 only).

Speaks the same {command, params} protocol over a WebSocket (/ws) and HTTP (POST /cmd) as Cua's computer-server,
adding a real AT-SPI accessibility tree, semantic control of the user's Chrome over CDP, and a takeover lock that
pauses agent input while a person is using the computer.
"""
