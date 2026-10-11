"""Write CI-only Xcode settings without treating URL slashes as comments."""
import os
from pathlib import Path


def encode_value(value: str) -> str:
    if '\n' in value or '\r' in value:
        raise ValueError('Xcode settings must be single-line values')
    return value.replace('//', '/$()/')


def write_config(environment: dict[str, str], output: Path) -> None:
    values = {key: environment.get(key, '') for key in (
        'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'WEB_JOIN_BASE_URL',
        'LIVEKIT_TOKEN_ENDPOINT', 'LIVEKIT_BETA_ENABLED',
    )}
    # Unit and UI tests use mocks. Fork PRs do not receive repository secrets.
    if not values['SUPABASE_URL'] or not values['SUPABASE_ANON_KEY']:
        values['SUPABASE_URL'] = 'https://ci-test.supabase.co'
        values['SUPABASE_ANON_KEY'] = 'test-only.anon.not-a-real-signature'
    values['TEAM_ID'] = 'LPHP8KBWW8'
    output.write_text(''.join(f'{key} = {encode_value(value)}\n' for key, value in values.items()))


if __name__ == '__main__':
    write_config(dict(os.environ), Path('Secrets.xcconfig'))
