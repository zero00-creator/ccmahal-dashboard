import { readFileSync } from 'node:fs'
import { after, before, test } from 'node:test'
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing'
import { ref, get, set, update, remove } from 'firebase/database'

const OWNER = 'claudemahal777@gmail.com'
const OWNER_UID = 'MPEdWykUOaUYDi3SAYcTmBVdpfA2'
const snap = (over = {}) => ({ v: 1, project: 'p', session: 's', status: 'running', seenAt: 1, ...over })
let env

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules',
    database: { rules: readFileSync(new URL('../database.rules.json', import.meta.url), 'utf8'), host: '127.0.0.1', port: 9000 },
  })
})
after(async () => env?.cleanup())

const as = (uid, email = `${uid}@example.com`) => env.authenticatedContext(uid, { email }).database()
const anon = () => env.unauthenticatedContext().database()

test('a person writes and reads their own session', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/live/s1'), snap()))
  const got = await assertSucceeds(get(ref(a, 'users/uidA/live/s1')))
  assert(got.val().project === 'p')
})

test('a person cannot read or write another person\'s data', async () => {
  await env.withSecurityRulesDisabled(async ctx => set(ref(ctx.database(), 'users/uidA/live/s1'), snap()))
  const b = as('uidB')
  await assertFails(get(ref(b, 'users/uidA/live')))
  await assertFails(get(ref(b, 'users/uidA/live/s1')))
  await assertFails(set(ref(b, 'users/uidA/live/x'), snap()))
  await assertFails(remove(ref(b, 'users/uidA/live/s1')))
  await assertFails(set(ref(b, 'users/uidA/other'), { a: 1 }))
})

test('a signed-out client reads and writes nothing', async () => {
  const x = anon()
  await assertFails(get(ref(x, 'users/uidA/live')))
  await assertFails(set(ref(x, 'users/uidA/live/s1'), snap()))
  await assertFails(get(ref(x, 'live')))
})

test('nobody can read the root or the users folder as a whole', async () => {
  const a = as('uidA')
  await assertFails(get(ref(a, '/')))
  await assertFails(get(ref(a, 'users')))
})

test('a snapshot without v, or with a wrong v, or without a required field is refused', async () => {
  const a = as('uidA')
  await assertFails(set(ref(a, 'users/uidA/live/bad1'), { project: 'p', session: 's', status: 'x', seenAt: 1 }))
  await assertFails(set(ref(a, 'users/uidA/live/bad2'), snap({ v: 2 })))
  await assertFails(set(ref(a, 'users/uidA/live/bad3'), { v: 1, project: 'p' }))
})

test('a person can delete their own entry', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/live/gone'), snap()))
  await assertSucceeds(remove(ref(a, 'users/uidA/live/gone')))
})

test('nothing but live, asks and prefs can be created under your own folder', async () => {
  const a = as('uidA')
  await assertFails(set(ref(a, 'users/uidA/devices/d1'), { fcmToken: 't' }))
  await assertFails(set(ref(a, 'users/uidA/junk'), { a: 1 }))
})

test('transitional: only the owner account (by uid) reaches the old live folder', async () => {
  const owner = as(OWNER_UID, OWNER)
  await assertSucceeds(set(ref(owner, 'live/s1'), snap()))
  await assertSucceeds(get(ref(owner, 'live')))
  const other = as('uidX')
  await assertFails(get(ref(other, 'live')))
  await assertFails(set(ref(other, 'live/s2'), snap()))
})

test('another account that carries the owner email claim is not the owner', async () => {
  const imposter = as('uidImposter', OWNER)
  await assertFails(get(ref(imposter, 'live')))
  await assertFails(set(ref(imposter, 'live/s3'), snap()))
})

const full = () => snap({
  title: 'T', firstSeen: 1700000000000, host: 'abcd1234',
  main: { model: 'm', effort: 'e', mode: 'auto', isRunning: true },
  meter: { ctxPct: 4, costUsd: 1.5, compactions: 0, limits: [{ kind: '5h', pct: 3 }] },
  flow: null,
  gate: { allowed: 1, you: 0, pending: 0, denied: 0 },
  agents: [{ id: 'a1', type: 'coder-low', task: 'x', model: 'm', status: 'running', startedAt: 1, endedAt: null, ctxPct: 3, costUsd: 0.1, stepDone: 1, stepTotal: 4, stepNote: 'n' }],
})

test('the real snapshot shape the plugin sends is accepted, and so is its heartbeat', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/live/real'), full()))
  await assertSucceeds(update(ref(a, 'users/uidA/live/real'), { seenAt: 1700000001000 }))
  await assertSucceeds(update(ref(a, 'users/uidA/live/real'), { status: 'ended', seenAt: 1700000002000 }))
})

test('oversized or wrongly typed data is refused', async () => {
  const a = as('uidA')
  await assertFails(set(ref(a, 'users/uidA/live/big1'), snap({ project: 'x'.repeat(500) })))
  await assertFails(set(ref(a, 'users/uidA/live/big2'), snap({ seenAt: 'soon' })))
  await assertFails(set(ref(a, 'users/uidA/live/big3'), snap({ extra: 'not allowed' })))
  const many = full()
  many.agents = Array.from({ length: 30 }, (_, i) => ({ id: `a${i}`, type: 't', task: 'x', status: 'running' }))
  await assertFails(set(ref(a, 'users/uidA/live/big4'), many))
  const longTask = full()
  longTask.agents[0].task = 'y'.repeat(1000)
  await assertFails(set(ref(a, 'users/uidA/live/big5'), longTask))
  await assertFails(set(ref(a, 'users/uidA/live/big6'), { ...snap(), main: { model: 'z'.repeat(1000) } }))
})

const ask = (over = {}) => ({ v: 1, tool: 'Bash', detail: 'rm -rf build', why: 'deletes files', session: 'my project', createdAt: 1700000000000, status: 'pending', ...over })

test('asks: the plugin creates one, the app answers it once, the plugin settles it', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/asks/s1/k1'), ask()))
  await assertSucceeds(update(ref(a, 'users/uidA/asks/s1/k1'), { answer: 'allow' }))
  await assertSucceeds(update(ref(a, 'users/uidA/asks/s1/k1'), { status: 'allowed', answeredBy: 'app' }))
  await assertSucceeds(remove(ref(a, 'users/uidA/asks/s1/k1')))
})

test('asks: an answer is refused once the ask is no longer pending', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/asks/s1/k2'), ask({ status: 'expired' })))
  await assertFails(update(ref(a, 'users/uidA/asks/s1/k2'), { answer: 'allow' }))
  await assertSucceeds(set(ref(a, 'users/uidA/asks/s1/k3'), ask()))
  await assertSucceeds(update(ref(a, 'users/uidA/asks/s1/k3'), { status: 'denied', answeredBy: 'app' }))
  await assertFails(update(ref(a, 'users/uidA/asks/s1/k3'), { answer: 'allow' }))
})

test('asks: the first answer stands, a later one cannot change it', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/asks/s1/k10'), ask()))
  await assertSucceeds(update(ref(a, 'users/uidA/asks/s1/k10'), { answer: 'deny' }))
  await assertFails(update(ref(a, 'users/uidA/asks/s1/k10'), { answer: 'allow' }))
})

test('asks: only allow or deny count as an answer, and shapes are capped', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/asks/s1/k4'), ask()))
  await assertFails(update(ref(a, 'users/uidA/asks/s1/k4'), { answer: 'maybe' }))
  await assertFails(set(ref(a, 'users/uidA/asks/s1/k5'), ask({ detail: 'x'.repeat(500) })))
  await assertFails(set(ref(a, 'users/uidA/asks/s1/k6'), ask({ status: 'weird' })))
  await assertFails(set(ref(a, 'users/uidA/asks/s1/k7'), ask({ extra: 1 })))
  await assertFails(set(ref(a, 'users/uidA/asks/s1/k8'), { v: 1, tool: 'Bash' }))
})

test('asks: nobody else can read, answer or create one', async () => {
  await env.withSecurityRulesDisabled(async ctx => set(ref(ctx.database(), 'users/uidA/asks/s9/k1'), ask()))
  const b = as('uidB')
  await assertFails(get(ref(b, 'users/uidA/asks/s9/k1')))
  await assertFails(update(ref(b, 'users/uidA/asks/s9/k1'), { answer: 'allow' }))
  await assertFails(set(ref(b, 'users/uidA/asks/s9/k2'), ask()))
  await assertFails(get(ref(anon(), 'users/uidA/asks')))
})

test('prefs: only appAsk, only a boolean, only your own', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/prefs/appAsk'), true))
  await assertFails(set(ref(a, 'users/uidA/prefs/appAsk'), 'yes'))
  await assertFails(set(ref(a, 'users/uidA/prefs/other'), true))
  await assertFails(set(ref(as('uidB'), 'users/uidA/prefs/appAsk'), true))
})

const cmd = (over = {}) => ({ v: 1, target: 'main', text: 'please pause after this step', createdAt: 1700000000000, status: 'queued', ...over })

test('cmd: the app queues one, the plugin delivers it, then clears it', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/cmd/s1/c1'), cmd()))
  await assertSucceeds(update(ref(a, 'users/uidA/cmd/s1/c1'), { status: 'delivered', deliveredAt: 1700000001000 }))
  await assertSucceeds(remove(ref(a, 'users/uidA/cmd/s1/c1')))
})

test('cmd: a failed one carries a note; a quick action is one of four', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/cmd/s1/c2'), cmd({ quick: 'stop', target: 'all' })))
  await assertSucceeds(update(ref(a, 'users/uidA/cmd/s1/c2'), { status: 'failed', note: 'too old' }))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c3'), cmd({ quick: 'explode' })))
})

test('cmd: it can only be created queued, with no note or delivery time', async () => {
  const a = as('uidA')
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c4'), cmd({ status: 'delivered' })))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c5'), cmd({ note: 'hi' })))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c6'), cmd({ deliveredAt: 1 })))
})

test('cmd: the text and target cannot change, and a status cannot go back or sideways', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/cmd/s1/c7'), cmd()))
  await assertFails(update(ref(a, 'users/uidA/cmd/s1/c7'), { text: 'something else' }))
  await assertFails(update(ref(a, 'users/uidA/cmd/s1/c7'), { target: 'all' }))
  await assertSucceeds(update(ref(a, 'users/uidA/cmd/s1/c7'), { status: 'delivered' }))
  await assertFails(update(ref(a, 'users/uidA/cmd/s1/c7'), { status: 'queued' }))
  await assertFails(update(ref(a, 'users/uidA/cmd/s1/c7'), { status: 'failed' }))
})

test('cmd: shapes are capped and closed', async () => {
  const a = as('uidA')
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c8'), cmd({ text: 'x'.repeat(501) })))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c9'), cmd({ target: 'y'.repeat(41) })))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c10'), cmd({ extra: 1 })))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c11'), { v: 1, target: 'main' }))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c12'), cmd({ v: 2 })))
  await assertFails(set(ref(a, 'users/uidA/cmd/s1/c13'), cmd({ text: '' })))
  await assertFails(update(ref(a, 'users/uidA/cmd/s1/c7'), { note: 'z'.repeat(81) }))
})

test('cmd: nobody else can read, queue or change one', async () => {
  await env.withSecurityRulesDisabled(async ctx => set(ref(ctx.database(), 'users/uidA/cmd/s9/c1'), cmd()))
  const b = as('uidB')
  await assertFails(get(ref(b, 'users/uidA/cmd/s9/c1')))
  await assertFails(set(ref(b, 'users/uidA/cmd/s9/c2'), cmd()))
  await assertFails(update(ref(b, 'users/uidA/cmd/s9/c1'), { status: 'delivered' }))
  await assertFails(get(ref(anon(), 'users/uidA/cmd')))
})

test('prefs: appCmd is a boolean too', async () => {
  const a = as('uidA')
  await assertSucceeds(set(ref(a, 'users/uidA/prefs/appCmd'), true))
  await assertFails(set(ref(a, 'users/uidA/prefs/appCmd'), 'yes'))
})

function assert(cond) {
  if (!cond) throw new Error('assertion failed')
}
