# Invoice Manager - Cross-Platform Business Suite (Flutter + Supabase)

A cross-platform billing, invoice management, and delivery challan application built with **Flutter** for **Android** and **Web** (deployable on **Vercel**), backed by **Supabase Cloud Database** and **Hive Offline Cache**.

---

## Key Features

1. **Unique 8-Character Invoice Codes (`INV-XXXXXXXX`)**:
   - Cryptographically random 8-character codes from an unambiguous 32-character alphabet (no confusing `0/O` or `1/I`).
   - Guarantees 100% collision-free uniqueness against both cloud and local records.
   - Manual override toggle for editing or custom numbers.

2. **Supabase Cloud + 100% Offline Local Cache**:
   - Real-time cloud database on **Supabase** (`nspinvproject`).
   - High-speed local **Hive** NoSQL cache on device: works completely offline and synchronizes when connected.

3. **Multi-Platform Ready**:
   - **Android App**: Standalone release APK (`app-release.apk`).
   - **Live Web App**: Pre-built static bundle in `build/web` with `vercel.json` for 1-click hosting on Vercel.

4. **Customer Modes**:
   - **Saved Customers**: Autocomplete search with auto-filling address, phone, and previous invoice pricing history.
   - **Side Delivery**: Dedicated mode for direct recipient name, address, and mobile number.
   - **New Customer**: Quick entry without pre-existing database record.

5. **Dynamic Products & Price Lists**:
   - Filter by active price lists (e.g. `Old`, `New`).
   - Dynamic items table with auto-suggested rates, quantities, description, discount %, and per-unit delivery charges.
   - Auto-remembers the last price charged for any product.

6. **On-Device PDF & Delivery Order Challan**:
   - **Invoice PDF**: Professional A4 layout with company header, logo, customer details, line items table, financial summary (Gross, Discount, Net, Delivery, Grand Total), notes, and signature block.
   - **Delivery Order Challan**: Clean delivery document showing quantities, items, and delivery instructions without financial pricing.
   - Direct print, PDF download, and WhatsApp/system sharing.

7. **Google Sheets Real-Time Sync**:
   - Built-in sync engine that fetches CSV exports directly from Google Sheets (Users, Customers, and Price Lists).
   - Protects Super Admin and local admin-created users from being overwritten or deleted.

8. **Role-Based Access Control**:
   - **Super Admin**: Complete system control, PDF designer, user permissions, database management.
   - **Admin**: User management, customers, products, price lists, sync, settings.
   - **User**: Standard billing, feature-gated permissions (`createInvoice`, `invoiceHistory`).

---

## Default Login Credentials

| Role | User ID | Password | Notes |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `0505` | `Manha@0505` | Master Administrator (protected system account) |
| **Admin** | `HO4` | `112233` | Synced from Sheet |
| **Admin** | `HO3` | `553388` | Synced from Sheet |

---

## Android APK Location

The release APK is compiled at:
```
build/app/outputs/flutter-apk/app-release.apk
```
You can transfer and install this APK directly on any Android phone or tablet.

---

## Vercel Deployment (From GitHub)

1. Push this repository to GitHub.
2. Go to [Vercel](https://vercel.com) and click **"Add New Project"**.
3. Import your GitHub repository.
4. Framework Preset: Choose **"Other"**.
5. Output Directory: Pre-configured via `vercel.json` as `build/web`.
6. Click **Deploy**. Your Invoice Web App is live!

---

## Development Commands

```bash
# Run on connected device or Chrome
flutter run

# Run unit tests
flutter test

# Build Android release APK
flutter build apk --release

# Build Web release
flutter build web --release
```
