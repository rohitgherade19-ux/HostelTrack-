import hashlib


def hash_password(password):
    """SHA-256 hash as 64 hex characters, same as MySQL SHA2(text, 256)."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest()