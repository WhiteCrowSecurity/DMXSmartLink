# Activate your licence

**Who this is for:** anyone who has just bought DMX Smart Link, or is moving it to a new machine.

**What you need:** the activation code from your receipt. It looks like `DMXSL-ABCD-1234-WXYZ`.

**How long:** about a minute online, or five minutes if the hub has no internet.

---

## Which path applies to you

| What you bought | What to do |
| --- | --- |
| An **annual licence** — you were emailed a licence key | Paste the key into Settings → `LICENSE_KEY`, press **Save settings**. Done; skip the rest of this guide. |
| A **multi-year licence or a hub** — you were given an activation **code** | Follow the steps below. |

---

## The quick way (hub has internet)

1. Open the hub in a browser and go to **Settings**.
2. Find **Activation code from your receipt** near the top of the page.
3. Type or paste your code.
4. Press **Activate online**.
5. The hub fetches your licence and fills it in. You should see it confirmed on the page.

That is the whole thing. If it worked, stop here.

---

## The manual way (hub has no internet, or the button did not work)

This path needs no terminal and no script — a browser on your phone is enough.

1. On the hub, go to **Settings**.
2. Find **Activation ID**. Press **Copy** next to it. It is a long string like
   `0C185-7574B-A96A1-890EF-E692D-EABEC`, and it identifies this machine.
3. On any device with internet, open **<https://dmxsmartlink.whitecrowsecurity.com/activate>**.
4. Enter your **activation code** and paste the **Activation ID**.
5. The page gives you a licence key. Copy it.
6. Back on the hub, paste it into **LICENSE_KEY** and press **Save settings**.

If you cannot get the Activation ID off the machine, you can leave it blank on the form. You will get
a licence that is not tied to a machine, which still works.

---

## Good to know

**One code covers three machines.** Activate on a Pi, a laptop and a spare, and the code handles all
three. After that, email support and we will sort it out — that is not a limit designed to catch you
out, it is there so a stolen code cannot be spread around.

**Re-activating the same machine is free.** If you reinstall, or run activation twice by accident, you
get the *same* licence back. It does not use up one of your three.

**Your licence never phones home.** After activation the hub checks the licence entirely on its own
machine. It does not need internet to start, to run, or to keep running — a hub on an isolated
network is a normal way to use this, not a workaround.

**Replacing a dead SD card on a Pi.** Move the card to a new board and it keeps working — the machine
identity follows the card, not the board. A genuinely new install uses one of your three activations.

**Your licence is not in your backups.** A backup file deliberately never contains your licence key,
so a restored hub asks for its own. See [Back up and restore](SOP-BACKUP-AND-RESTORE.md).

---

## If something goes wrong

| It says | What it means |
| --- | --- |
| "Enter the activation code from your receipt first." | The code box is empty. |
| The **Activate online** button reports it could not reach the server | The hub has no internet, or is behind a firewall. Use the manual way above — it is a supported path, not a fallback. |
| "Invalid license key" after pasting | Something was cut off in the copy. Paste it again, making sure you have the whole string with no spaces or line breaks. |
| Your licence has expired | Renew from the store, then paste the new key into `LICENSE_KEY`. |

Still stuck? Email **support@dmxsmartlink.com** with your order number and your Activation ID. Do not
email your licence key to anyone who has not asked for it.
