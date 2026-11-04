const form = document.querySelector('#test');
const accept = document.querySelector('#accept');
const button = document.querySelector('#run');
const status = document.querySelector('#status');
const result = document.querySelector('#result');

const supported = window.isSecureContext && location.protocol === 'https:'
  && typeof WebAssembly === 'object' && typeof Worker === 'function'
  && typeof AbortSignal.timeout === 'function' && typeof crypto.randomUUID === 'function';
const phases = {
  assets: 'Loading the browser client and signed directory…',
  connect: 'Opening an Anyone circuit…',
  retry: 'Retrying the circuit…',
  request: 'Sending the HTTPS request through Anyone…',
};
let running = false;

function syncButton() {
  button.disabled = !supported || !accept.checked || running;
  accept.disabled = running;
}

status.textContent = supported
  ? 'Ready when you are.'
  : 'Open the demo in a current browser using the trusted local HTTPS address.';
syncButton();
accept.addEventListener('change', syncButton);

form.addEventListener('submit', async event => {
  event.preventDefault();
  if (!supported || !accept.checked || running) return;
  running = true;
  syncButton();
  result.hidden = true;
  status.textContent = 'Checking whether the signed directory is ready…';

  try {
    const health = await fetch('/wasm-lab/health', { signal: AbortSignal.timeout(3000) });
    if (!health.ok) throw new Error('The local directory is unavailable. Wait for the first sync, then retry.');

    const startedAt = Date.now();
    status.textContent = phases.assets;
    await import('/wasm-lab/client.js');
    const report = await window.AnyoneWasmLab.measure(
      crypto.randomUUID(), phase => { status.textContent = phases[phase] ?? 'Running the test…'; }, startedAt,
    );

    document.querySelector('#exit-ip').textContent = report.ip;
    document.querySelector('#session').textContent = report.reusedSession ? 'Reused (warm)' : 'New';
    document.querySelector('#setup').textContent = report.startupMs + ' ms';
    document.querySelector('#request').textContent = report.requestMs + ' ms';
    document.querySelector('#total').textContent = report.elapsedMs + ' ms';
    document.querySelector('#test-id').textContent = report.nonce;
    result.hidden = false;
    button.textContent = 'Run again';
    status.textContent = 'Test complete.';
  } catch (error) {
    status.textContent = error instanceof Error ? error.message : 'The test could not complete.';
  } finally {
    running = false;
    syncButton();
  }
});
