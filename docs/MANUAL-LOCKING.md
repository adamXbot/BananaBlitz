# Locking a path by hand

The same result as the app's *Lock with Immutable File* strategy, done in Finder.
Useful for a single path you do not want to add to the target registry.

![manual](https://github.com/user-attachments/assets/e4b5a561-a46c-47f2-ad6a-c9db3b4f789d)

1. Open TextEdit and create a file.
2. Remove the extension and make sure it is spelt **exactly** the same as the
   folder you are replacing.
3. Delete the folder in your `~/Library` folder.
4. Quickly drag the file across — e.g. `Trial`.
5. Right-click the file and choose Lock.

That's it. The daemon now finds a locked file where its directory used to be and
cannot recreate it.

To undo it, unlock the file in Finder's Get Info panel (or `chflags nouchg`),
delete it, and recreate the directory — which is exactly what
[`Scripts/unbrick.sh`](../Scripts/unbrick.sh) does for the registry targets.
