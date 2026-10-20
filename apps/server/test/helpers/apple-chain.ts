// Builds throw-away certificate chains shaped like Apple's (ECDSA P-256 leaf, Apple marker extensions) with the
// openssl CLI, and signs JWS payloads with them, for apple-jws.test.ts. Nothing here is Apple's: tests trust their
// own root explicitly via `{ roots: [...] }`. Ported from the 187 (Majlis187) api-server's equivalent helper,
// which this app's apple-jws.ts itself was ported from.
import { execFileSync } from 'node:child_process';
import { createPrivateKey, sign } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const run = (cwd: string, ...args: string[]) => execFileSync('openssl', args, { cwd, stdio: 'pipe' });
const LEAF_OID = '1.2.840.113635.100.6.11.1';
const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

export interface Chain {
  rootPem: string;
  x5c: [string, string, string];
  leafKey: string;
}

export function makeChain({ markers = true, name = 'Test' }: { markers?: boolean; name?: string } = {}): Chain {
  const dir = mkdtempSync(path.join(tmpdir(), 'apple-chain-'));
  try {
    for (const who of ['root', 'int', 'leaf']) run(dir, 'ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', `${who}.key`);
    run(
      dir,
      'req',
      '-new',
      '-x509',
      '-key',
      'root.key',
      '-subj',
      `/CN=${name} Root`,
      '-days',
      '3650',
      '-out',
      'root.pem',
      '-addext',
      'basicConstraints=critical,CA:TRUE',
      '-addext',
      'keyUsage=critical,keyCertSign',
    );
    const issue = (subject: string, issuerPem: string, issuerKey: string, key: string, out: string, extra: string) => {
      run(dir, 'req', '-new', '-key', key, '-subj', `/CN=${name} ${subject}`, '-out', `${subject}.csr`);
      writeFileSync(path.join(dir, `${subject}.ext`), `[ext]\n${extra}\n`);
      run(dir, 'x509', '-req', '-in', `${subject}.csr`, '-CA', issuerPem, '-CAkey', issuerKey, '-CAcreateserial', '-days', '3650', '-out', out, '-extfile', `${subject}.ext`, '-extensions', 'ext');
    };
    issue('int', 'root.pem', 'root.key', 'int.key', 'int.pem', `basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign${markers ? `\n${INTERMEDIATE_OID}=ASN1:NULL` : ''}`);
    issue('leaf', 'int.pem', 'int.key', 'leaf.key', 'leaf.pem', `basicConstraints=CA:FALSE${markers ? `\n${LEAF_OID}=ASN1:NULL` : ''}`);
    const der = (file: string) => run(dir, 'x509', '-in', file, '-outform', 'DER').toString('base64');
    return {
      rootPem: readFileSync(path.join(dir, 'root.pem'), 'utf8'),
      x5c: [der('leaf.pem'), der('int.pem'), der('root.pem')],
      leafKey: readFileSync(path.join(dir, 'leaf.key'), 'utf8'),
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** A self-signed leaf posing as a full chain: it claims to be its own intermediate and root. */
export function makeSelfSigned(): Chain {
  const dir = mkdtempSync(path.join(tmpdir(), 'apple-self-'));
  try {
    run(dir, 'ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', 'k.key');
    run(dir, 'req', '-new', '-x509', '-key', 'k.key', '-subj', '/CN=Self', '-days', '3650', '-out', 'c.pem', '-addext', `${LEAF_OID}=ASN1:NULL`);
    const der = run(dir, 'x509', '-in', 'c.pem', '-outform', 'DER').toString('base64');
    return { x5c: [der, der, der], leafKey: readFileSync(path.join(dir, 'k.key'), 'utf8'), rootPem: readFileSync(path.join(dir, 'c.pem'), 'utf8') };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function signJws(payload: object, { x5c, leafKey }: Chain, headerOverride: Record<string, unknown> = {}): string {
  const enc = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const head = enc({ alg: 'ES256', x5c, ...headerOverride });
  const body = enc(payload);
  const signature = sign('sha256', Buffer.from(`${head}.${body}`), { key: createPrivateKey(leafKey), dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${head}.${body}.${signature}`;
}
