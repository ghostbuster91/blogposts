# Window switcher
\#qmk \#keyboard

At this point I am not sure if this feature has any official name. I have seen it called "window switcher", "fast switcher", "super alt tab" and others.
For the sake of this blogpost I will stick to the "window switcher" name. I also don't know who came up with this idea first. If you know please let me know.

## What is it?

"Window switcher" is a custom action that can be bound to any key. It will send `ALT+TAB` but hold `ALT` between consecutive key presses.
`ALT` is released when some other key is pressed or when the timeout is reached.

An example implementation is provided in qmk docs: https://docs.qmk.fm/#/feature_macros?id=super-alt%e2%86%aftab

## Beyond the basics

Although the example implementation works well it is very basic. We can extend it further by allowing to hit `SHIFT+TAB` key which will
allow us to move in both directions when switching windows.

But there is more. On linux you can also narrow the scope of switching windows to only choose between windows of the same type. This is achieved by
pressing ``ALT+` ``. Analogically we can move backwards by holding the `SHIFT` modifier. I use it to switch between chrome windows as I constantly have
multiple windows open, each one with a different profile.

Let's summarize. We can trigger "window switcher" using one key, let's call it `STAB1`. We can then move backwards by pressing `STAB2`.
And we also have the same but for windows of the same type. Do we need 4 keys to cover all of that? Luckily we don't :)

This can be implement in a convenient and concise way with only two keys by taking order of key presses into account.

For example, pressing first `STAB1` should invoke regular "window switcher", and keep the `ALT` modifier registered. Calling then `STAB2` should just move backwards in
the already visible window switcher by sending `SHIFT+TAB`. On the other hand, pressing first `STAB2` could invoke "same type window switcher", and keep the `ALT` modifier registered.
Then pressing `STAB1` would move us backwards in the already visible window switcher by sending ``SHIFT+` ``.

You can check the implementation in my keymap: https://github.com/ghostbuster91/qmk_firmware/blob/b1ee57b687bffda5598ae23916d92ad7225b6a7d/keyboards/bastardkb/tbkmini/keymaps/ghostbuster91/keymap.c#L174
