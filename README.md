Comet (Perplexity’s browser) blocks extensions from running on the Perplexity website / the Comet new tab page (they possibly do this so no adblock extensions can block Perplexity's ads/trackers?).

This means extensions like [Complexity](https://github.com/pnd280/complexity) couldn't work.

This repo ships a tiny macOS script that makes a wrapper app / shortcut named **Comet - CPLX** in `~/Applications`. Launching it flips a setting right before Comet starts so extensions run there. No sudo required, and does not modify `Comet.app` itself!

More background:
[https://github.com/pnd280/complexity/blob/nxt/perplexity/extension/docs/comet-enable-extensions.md#tldr](https://github.com/pnd280/complexity/blob/nxt/perplexity/extension/docs/comet-enable-extensions.md#tldr)

## One-click install

```bash
curl -fsSL "https://raw.githubusercontent.com/theJayTea/Comet-Patcher-to-Unblock-Perplexity-Extensions/main/comet-patch-macos.sh" | bash
```

After it runs, open **Comet - CPLX** via Spotlight or `~/Applications`, and pin it to your Dock if you want.

Extensions will now be able to work on Perplexity when using Comet :) Great for adblock and stuff like Complexity.

## What it does

* Creates `~/Applications/Comet - CPLX.app`
* On launch:

  1. Quits Comet if it’s running
  2. Sets `"Allow-external-extensions-scripting-on-NTP": true` in
     `~/Library/Application Support/Comet/Local State`
  3. Starts the real Comet
* Logs to `~/Library/Logs/Comet-CPLX.log`

## Manual install

```bash
bash comet-patch-macos.sh
```

Then launch **Comet - CPLX** and use that going forward.

## Why this exists

Comet keeps that flag at `false`, which blocks extension scripts on Perplexity’s pages. Flipping it to `true` right before launch lets Complexity and other extensions run for the session. The developer of Complexity [Pham Ngoc Duong](https://github.com/pnd280), [discovered](https://github.com/pnd280/complexity/blob/nxt/perplexity/extension/docs/comet-enable-extensions.md#tldr) the workaround on Windows! I ported the workaround to macOS and built this one-click installer.


## Uninstall

Delete `~/Applications/Comet - CPLX.app`. You can also remove `~/Library/Logs/Comet-CPLX.log`.

## Troubleshooting

* If Comet isn’t found, you’ll be prompted to select `Comet.app` (we ~~steal~~ borrow its icon for the modded shortcut haha)
* If the script “worked” but extensions still don’t run, make sure you launched **Comet - CPLX** and not the old Dock icon!
