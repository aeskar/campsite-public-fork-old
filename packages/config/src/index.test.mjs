import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { after, describe, it } from 'node:test'

// Plain .mjs so it runs on Node 20 without type stripping. The sources hold no TypeScript-only
// syntax, so a copy with explicit extensions (Node cannot resolve `./slack`) can be imported as is.
// If type annotations are ever added to them, switch this test to a TS runner.
const dir = mkdtempSync(join(tmpdir(), 'campsite-config-'))
const here = dirname(fileURLToPath(import.meta.url))
const src = join(here, 'index.ts')

writeFileSync(join(dir, 'index.mjs'), readFileSync(src, 'utf8').replace("from './slack'", "from './slack.mjs'"))
cpSync(join(here, 'slack.ts'), join(dir, 'slack.mjs'))

after(() => rmSync(dir, { recursive: true, force: true }))

function loadConfig(env) {
  const baseEnv = { ...process.env }

  for (const key of Object.keys(baseEnv)) {
    if (key.startsWith('NEXT_PUBLIC_')) delete baseEnv[key]
  }

  const result = spawnSync(
    process.execPath,
    [
      '--input-type=module',
      '-e',
      `import * as c from ${JSON.stringify(join(dir, 'index.mjs'))}; console.log(JSON.stringify(c))`
    ],
    { env: { ...baseEnv, ...env }, encoding: 'utf8' }
  )

  assert.equal(result.status, 0, result.stderr)
  return JSON.parse(result.stdout)
}

describe('config from environment', () => {
  it('reads NEXT_PUBLIC_API_URL in production', () => {
    const config = loadConfig({ NODE_ENV: 'production', NEXT_PUBLIC_API_URL: 'https://api.camp.aeskar.com' })

    assert.equal(config.RAILS_API_URL, 'https://api.camp.aeskar.com')
  })

  it('reads every NEXT_PUBLIC value in production', () => {
    const config = loadConfig({
      NODE_ENV: 'production',
      NEXT_PUBLIC_WEB_URL: 'https://camp.aeskar.com',
      NEXT_PUBLIC_AUTH_URL: 'https://auth.camp.aeskar.com',
      NEXT_PUBLIC_SYNC_URL: 'wss://sync.camp.aeskar.com',
      NEXT_PUBLIC_IMGIX_DOMAIN: 'https://img.camp.aeskar.com',
      NEXT_PUBLIC_PUSHER_KEY: 'soketi-key',
      NEXT_PUBLIC_PUSHER_HOST: 'ws.camp.aeskar.com',
      NEXT_PUBLIC_PUSHER_PORT: '443',
      NEXT_PUBLIC_PUSHER_TLS: 'true',
      NEXT_PUBLIC_WEB_PUSH_PUBLIC_KEY: 'vapid-public'
    })

    assert.equal(config.WEB_URL, 'https://camp.aeskar.com')
    assert.equal(config.RAILS_AUTH_URL, 'https://auth.camp.aeskar.com')
    assert.equal(config.SYNC_URL, 'wss://sync.camp.aeskar.com')
    assert.equal(config.IMGIX_DOMAIN, 'https://img.camp.aeskar.com')
    assert.equal(config.PUSHER_KEY, 'soketi-key')
    assert.equal(config.PUSHER_HOST, 'ws.camp.aeskar.com')
    assert.equal(config.PUSHER_PORT, 443)
    assert.equal(config.PUSHER_TLS, true)
    assert.equal(config.WEB_PUSH_PUBLIC_KEY, 'vapid-public')
  })

  it('keeps upstream production constants when unset', () => {
    const config = loadConfig({ NODE_ENV: 'production' })

    assert.equal(config.RAILS_API_URL, 'https://api.campsite.com')
    assert.equal(config.IMGIX_DOMAIN, 'https://campsite.imgix.net')
    assert.equal(config.PUSHER_KEY, '1301e1180de87095b1c0')
    assert.equal(config.PUSHER_HOST, undefined)
    assert.equal(config.PUSHER_PORT, undefined)
  })

  it('disables TLS only when NEXT_PUBLIC_PUSHER_TLS is false', () => {
    assert.equal(loadConfig({ NEXT_PUBLIC_PUSHER_TLS: 'false' }).PUSHER_TLS, false)
    assert.equal(loadConfig({}).PUSHER_TLS, true)
  })
})
