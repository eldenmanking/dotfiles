# Windows setup notes
> **Note:** Windows can be installed as Windows To Go onto a standalone USB drive only with [Rufus](https://rufus.ie), which requires an existing Windows machine or VM.

* Make Chrome the default instead of uninstalling Edge (tested on Windows 11)
    * Settings > Apps > Default apps > Google Chrome > Set default. This moves `.htm`, `.html`, `http` and `https`.
    * On that same Chrome page, open each of `.mhtml`, `.pdf`, `.svg`, `.xht` and `.xhtml` and pick Google Chrome.
    * For `.mht` and `.xml`, type the extension in "Set a default for a file type or link type", open it and pick Google Chrome (for `.mht` choose "Choose an app on your PC" > `chrome.exe`).
    * `ftp`, `microsoft-edge`, `microsoft-edge-holographic`, `ms-xbl-3d8b930f` and `read` stay on Edge: Chrome doesn't register them, so Windows doesn't offer it.
    * [Remove-MS-Edge](https://github.com/ShadowWhisperer/Remove-MS-Edge) is not used: it leaves `sfc /verifyonly` integrity violations and a dangling default-browser handler.
* [Disable OneDrive](https://support.microsoft.com/en-us/office/turn-off-disable-or-uninstall-onedrive-f32a17ce-3336-40fe-9c38-6efb09f944b0)
* [Disable "Hide pointer while typing"](https://answers.microsoft.com/en-us/windows/forum/all/mouse-cursor-disappears-in-any-dialogue-or-text/3b3f0664-9e30-4acd-9f20-d304fcc227e9)
* Download [keyrate](https://github.com/EricTetz/keyrate) to Program Files
    * [Schedule a task](https://stackoverflow.com/questions/76766511/how-do-i-automatically-have-a-command-run-from-my-windows-10-command-prompt-when) to run keyrate at login
* Remove apps from the taskbar, and the pinned apps and other sections from the start menu
* Optional
    * [Enable hibernate](https://answers.microsoft.com/en-us/windows/forum/all/how-can-one-enable-hibernate-in-windows-11-since/2545b402-4884-45b3-9fda-459bce2333d7)
    * [Install PowerToys](https://learn.microsoft.com/en-us/windows/powertoys/)
        * Map CAPS to ESC
    * Install Logi Options+ for Logitech peripheral management

