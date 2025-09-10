```
key: intro
```

# {docname_captured_scroll_wheels}

Mac Mouse Fix **captures your mouse's scroll wheel by default**, similar to how it [captures mouse buttons](<{language_root}Support/Guides/CapturedButtonsMMF3.md>).

```
comment:
```

```
key: uncapturing
```

**To prevent scroll wheel capture:**

1. Go to the 'Scrolling' tab in Mac Mouse Fix
2. Turn off **all** options
    - In case of the 'Speed' option, set it to 'macOS'
    - Remove all entries under 'Keyboard Modifiers' by clicking the 'x' button next to each modifier

After this, you should see a message indicating that the scroll wheel is no longer being captured.

```
comment:
```

```
key: uncapturing-purpose
```

**What happens when the scroll wheel is *no longer* being captured?**

Mac Mouse Fix will then completely ignore your scroll wheel – it won't use any processor power or battery charge during scrolling, or interfere in any way. This gives you complete freedom to use other apps like [MOS](https://mos.caldis.me/) to handle your scroll wheel.

```
comment:
```

```
key: also-see
```

## Also see

- [{docname_captured_buttons_mmf3}](<{language_root}Support/Guides/CapturedButtonsMMF3.md>)

*(Edited with excellent assistance by Claude 3.5 Sonnet)*

```
comment:
```

{guide_footer}

<!--
    Notes / thoughts: 

    - Should we call it 'capturing' for the scrollwheel? [Sep 2025]
      - Contra: MMF doesn't hide the scroll-events or prevent any default-actions in the same way it does for mouse buttons. 
      - Pro: Capturing is just used like 'Intercepting' by us. The 'hiding from other apps' thing that happens for buttons isn't inherent (But is pretty core to our 'CapturedButtonsMMF3' explation)
    - Should this article even exist? [Sep 2025]
        - - I don't think it's relevant to many users, 
        - + I think it may prevent confusion if we have consistent Capture Toasts for both the 'Capturing sideeffects' on the Buttons and the Scrolling Tab?
        - + The few users for whom it is useful may really appreciate it.
        - - Maybe this should be a footnote at the bottom of CapturedButtonsMMF3.md?
        - - Maintenance overhead. I'm already not including screenshots here and keeping the step-by-step instructions vague to reduce maintenance overhead – and if we do it badly, maybe better not do it at all?
    - Style [Sep 2025]
        - Compared to CapturedButtonsMMF3.md this is **not** broken up into section for maximum scannability. 
        - This is just a long explanatory, text. 
        - Should we break this up into sections like CapturedButtonsMMF3.md for maximum scannability?
            - - More effort
            - - Less laid back / conversational tone (?) (Not sure why I value that. Feels sorta appropriate for this. Since in some way explaining how to use 'competitor' apps might seem like a conflict of interest and sorta weird if I do it in a sterile tone or something? Not sure I'm making any sense.)
            - Easier to parse for readers
        - Should the 'how to uncapture' explanation really be first? [Sep 10 2025]
            - - Most people might come from the uncapturing notification – They'll already know how to uncapture.
            - + The '**What happens when the scroll wheel is *no longer* being captured?**' explanation below feels more natural after the explanation of how to uncapture. (And I think *no longer* is less likely to be missed.)
    - Everything takes me so much time
        - We should just ship this and if I really hate it later I can change it. It won't affect very many people I think.
-->
