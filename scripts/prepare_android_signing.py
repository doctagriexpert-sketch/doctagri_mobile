"""Prepare CI signing files without logging secrets; no publication."""
import base64
import os
from pathlib import Path


def property_value(value):
    # java.util.Properties.load(InputStream) expects Latin-1 plus Unicode escapes.
    escaped = []
    for char in value:
        if char in '\\:=#! ':
            escaped.append('\\' + char)
        elif char in '\n\r\t':
            escaped.append({'\n': '\\n', '\r': '\\r', '\t': '\\t'}[char])
        elif ord(char) > 126 or ord(char) < 32:
            raw = char.encode('utf-16-be')
            escaped.extend('\\u' + raw[i:i + 2].hex() for i in range(0, len(raw), 2))
        else:
            escaped.append(char)
    return ''.join(escaped)


def prepare(root, values):
    required = ('KEYSTORE_BASE64', 'STORE_PASSWORD', 'KEY_PASSWORD', 'KEY_ALIAS')
    if any(not values.get(key) for key in required):
        raise ValueError('Missing signing configuration; values are never printed.')
    data = base64.b64decode(''.join(values['KEYSTORE_BASE64'].split()), validate=True)
    if not data:
        raise ValueError('Empty keystore')
    store = root / 'android/app/release.jks'
    props = root / 'android/key.properties'
    if store.exists() or props.exists():
        raise FileExistsError('Signing files already exist; refusing to overwrite them.')
    store.parent.mkdir(parents=True, exist_ok=True)
    store.write_bytes(data)
    store.chmod(0o600)
    fields = {'storeFile': 'release.jks', 'storePassword': values['STORE_PASSWORD'],
              'keyPassword': values['KEY_PASSWORD'], 'keyAlias': values['KEY_ALIAS']}
    props.write_text(''.join(f'{key}={property_value(value)}\n' for key, value in fields.items()),
                     encoding='ascii')
    props.chmod(0o600)


if __name__ == '__main__':
    prepare(Path(__file__).resolve().parents[1], os.environ)
