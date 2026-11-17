# Command port lifetime

The port answers any process of the same user and cannot identify the sender, so it would let a process without Screen Recording or Accessibility read every window title and focus windows through AltTab's permissions. Release builds therefore open it only when the hidden `commandLineEnabled` preference is true (read at launch); debug builds always open it for the QA harness. A disabled port makes the CLI fail with a message naming the preference.

The main thread owns the local command port. Its callbacks run on the CLI thread and dispatch commands to the main thread. Observing an already registered port is idempotent. A failed registration must not mark the port as listening, so a later observation can try again.

Before launching a replacement AltTab process, invalidate the old command port and release its registered name. The replacement may start before the old process finishes terminating. It must be able to receive commands without waiting for that termination. Stopping an absent port is harmless, and observation can register again after a stop.

The lifecycle recovery journeys exercise real relaunches and require the replacement to answer and resume window switching. LIVE-RECOVERY-UI-01/02 also exercise Return after recovery and reopening after Escape in German and Arabic. Permissions and input failures are injected; the processes and command port are real.
