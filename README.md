# 🧪 WSS Buff System

![Buff UI Preview](https://media.discordapp.net/attachments/1448168670835638334/1449547144158777605/image.png?ex=693f4b7a\&is=693df9fa\&hm=90edb28fadcb3c695a5ca694f0b27629b63cec91e73c055f227ab0c0d79aa010&=\&format=webp\&quality=lossless\&width=269\&height=520)

A simple, clean **buff system for FiveM players** that provides temporary boosts such as speed, stamina, intelligence, and strength. Buffs are displayed on-screen, persist through reconnects, and automatically expire.

---

## ✨ What Are Buffs?

Buffs are **temporary bonuses** applied to your character. Once active, they:

* Appear on your screen with a timer
* Automatically apply their effect
* Expire on their own
* Resume if you disconnect and reconnect (if time remains)

You do **not** need to manage anything manually.

---

## 🧬 Available Buffs

| Buff             | Effect                                             |
| ---------------- | -------------------------------------------------- |
| **Speed**        | Increases run & sprint speed                       |
| **Stamina**      | Regenerates stamina continuously                   |
| **Focus**        | Reduces difficulty / timing in supported minigames |
| **Intelligence** | Increases time allowed in supported minigames      |
| **Strength**     | Increases inventory carry weight                   |

> Buff effects and durations are set by the server.

---

## ⏱️ Buff Timers

* Each buff shows a **countdown timer**
* Re-applying the same buff **extends** its duration
* Buffs automatically disappear when they expire

No action is required from the player.

---

## 🔁 Persistence (Reconnect Safe)

If you:

* Disconnect
* Crash
* Relog

Your buffs will be **restored automatically** with the remaining time.

---

## 🖥️ User Interface

* Buffs are displayed on the screen
* Each buff shows:

  * Name
  * Remaining duration
* UI updates automatically when buffs are added, extended, or removed

---

## ❓ Frequently Asked Questions

### Do buffs stack?

Yes. Applying the **same buff again extends its timer**.

### Can I have multiple buffs at once?

Yes. You can have **multiple different buffs active simultaneously**.

### Do I lose buffs on death?

No. Buffs only expire when their timer runs out or if removed by the server.

### Do buffs affect everyone the same?

Buff strength and duration are **server-controlled** and apply equally unless customized.

---

## 🛑 Important Notes

* Buff effects are automatic
* Buffs cannot be manually removed by players
* Exploits are prevented server-side

---

## 📦 Dependencies

This resource requires the following dependencies to function correctly:

* **community_bridge** – Framework abstraction (ESX / QBCore compatibility)
* **oxmysql** – Database persistence for buffs
* **ox_lib** – Command system and utilities
* **lation_ui** – UI initialization support
* **ox_inventory** – Required for the **Strength** buff (inventory weight increase)

> ⚠️ If `ox_inventory` is not installed, the Strength buff will have no effect.

---

## ❤️ Credits

Developed by **WSS-Development**
Buff System by **zStretz**

---

If you experience issues or have questions, contact a server administrator.
