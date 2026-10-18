// Compile, deploy and verify the controlled test tokens on Base Sepolia.
//   PADV=<padv keystore password> node evm/deploy_tokens.mjs
// Every token except HiddenToken is verified on Blockscout, so Skeptic can read
// its source. HiddenToken is deliberately left unverified.
import solc from 'solc';
import { Wallet, JsonRpcProvider, ContractFactory } from 'ethers';
import fs from 'fs'; import os from 'os'; import path from 'path'; import url from 'url';

const ROOT = path.join(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const PASS = process.env.PADV || '';
if (!PASS) { console.error('set PADV'); process.exit(1); }
const RPC = process.env.BASE_RPC || 'https://sepolia.base.org';
const EXPLORER = 'https://base-sepolia.blockscout.com';
const EVM = 'cancun';
const TOKENS = ['PlainToken', 'TrapToken', 'WhitewashedTrap', 'SmearedPlain', 'HiddenToken'];
const VERIFY = new Set(['PlainToken', 'TrapToken', 'WhitewashedTrap', 'SmearedPlain']);

const compilerVersion = 'v' + solc.version().replace(/\.Emscripten.*$/, '');
console.log('compiler', compilerVersion);

function compile(name) {
  const source = fs.readFileSync(path.join(ROOT, 'evm', name + '.sol'), 'utf8');
  const input = {
    language: 'Solidity',
    sources: { [name + '.sol']: { content: source } },
    settings: { optimizer: { enabled: true, runs: 200 }, evmVersion: EVM,
      outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } } },
  };
  const out = JSON.parse(solc.compile(JSON.stringify(input)));
  const errs = (out.errors || []).filter((e) => e.severity === 'error');
  if (errs.length) { for (const e of errs) console.error(e.formattedMessage); process.exit(1); }
  const c = out.contracts[name + '.sol'][name];
  return { source, abi: c.abi, bytecode: '0x' + c.evm.bytecode.object };
}

const provider = new JsonRpcProvider(RPC);
const ks = fs.readFileSync(path.join(os.homedir(), '.genlayer', 'keystores', 'padv.json'), 'utf8');
const wallet = (await Wallet.fromEncryptedJson(ks, PASS)).connect(provider);
console.log('deployer', wallet.address, 'balance', Number(await provider.getBalance(wallet.address)) / 1e18, 'ETH');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const outFile = path.join(ROOT, 'results', 'tokens.json');
const done = fs.existsSync(outFile) ? JSON.parse(fs.readFileSync(outFile, 'utf8')) : {};

for (const name of TOKENS) {
  const c = compile(name);
  if (!done[name]) {
    const factory = new ContractFactory(c.abi, c.bytecode, wallet);
    const contract = await factory.deploy();
    await contract.waitForDeployment();
    done[name] = { address: await contract.getAddress(), tx: contract.deploymentTransaction().hash, verified: false };
    console.log('deployed', name, done[name].address);
    fs.mkdirSync(path.dirname(outFile), { recursive: true });
    fs.writeFileSync(outFile, JSON.stringify(done, null, 2));
  } else {
    console.log('already deployed', name, done[name].address);
  }
  if (!VERIFY.has(name) || done[name].verified) continue;
  await sleep(8000);
  for (let attempt = 1; attempt <= 6; attempt++) {
    const res = await fetch(`${EXPLORER}/api/v2/smart-contracts/${done[name].address}/verification/via/flattened-code`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        compiler_version: compilerVersion, license_type: 'mit', source_code: c.source,
        is_optimization_enabled: true, optimization_runs: 200, contract_name: name,
        evm_version: EVM, autodetect_constructor_args: true, libraries: {},
      }),
    });
    const text = await res.text();
    console.log('  verify', name, res.status, text.slice(0, 160));
    if (res.ok) break;
    await sleep(10000 * attempt);
  }
}

// Confirm what Blockscout now says about each.
await sleep(20000);
for (const name of TOKENS) {
  const r = await fetch(`${EXPLORER}/api/v2/smart-contracts/${done[name].address}`).then((x) => x.json()).catch(() => ({}));
  done[name].verified = !!r.is_verified;
  console.log(name.padEnd(16), done[name].address, 'verified:', !!r.is_verified);
}
fs.writeFileSync(outFile, JSON.stringify(done, null, 2));
