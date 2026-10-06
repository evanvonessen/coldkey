# App icon sources

- `hotkey-original.png` is the unchanged 256 × 256 HotKey logo from the [MacUpdate listing](https://hotkey.macupdate.com/) explicitly named in the original Coldkey request. The listing identifies Peter Vorwieger / codenuts as the developer. [Original PNG](https://static.macupdate.com/products/61747/l/hotkey-logo.png?v=1606736412). This is the source used for the macOS app icon, restored at the user's request.
- `coldkey-liquid-glass.png` is the previous 1254 × 1254 transparent PNG, generated with OpenAI imagegen from that original logo at the user's earlier request. It is retained as an unused historical asset.

Both source images are retained unchanged. `scripts/build-app.sh` uses macOS `sips` and `iconutil` to generate the standard 16, 32, 128, 256, and 512 point representations at 1× and 2×, then installs `Coldkey.icns` in the app bundle's `Contents/Resources`. `CFBundleIconFile` refers to that file. The menu-bar template symbol remains separate.

Library source references:

- Original: `libfile_f7c431a3a86c8191855925bb05057b9d`.
- Previous glass image: `libfile_de74acbb4f408191b7aeeca09641f50e`, backing file `file_00000000cfcc81f5b671b2f5e8e09e46` (`exec-9513ada2-4593-40d2-a8fd-04aa8b029f6b.png`).
