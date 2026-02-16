# Glurg - Magic The Gathering Creature Combiner

A Flutter app for Magic: The Gathering players to easily manage "It Came from Planet Glurg" card combinations. Search for creatures, combine their stats, and display merged card details.

## Features (v1) ✅

- ✅ **Search Magic Cards** — Find creature cards by name using Scryfall API
- ✅ **Offline Mode** — Download 50,000+ creatures for offline play (~4 MB cache)
- ✅ **Combine Creatures** — Add multiple creatures and see combined stats instantly
- ✅ **Card Details** — View mana value, type line, power/toughness, and abilities
- ✅ **Double-Faced Cards** — Properly handles DFC cards and displays the correct face based on search
- ✅ **Supertypes & Card Types** — Shows Legendary, Snow, Artifact, Enchantment, etc.
- ✅ **Duplicate Creatures** — Add the same creature multiple times for flexible combining
- ✅ **Fast & Responsive** — Instant lookups with offline cache, <1 second with API

## Tech Stack

- **Flutter 3.41.1 / Dart 3.11.0** - Cross-platform mobile framework
- **Scryfall API** - Free, public MTG card database
- **SQLite (sqflite)** - Local creature database
- **Provider** - State management
- **HTTP** - Network requests with streaming downloads
- **Material Design 3** - Modern UI components

## Project Structure

```
lib/
├── main.dart                              # App entry point
├── models/
│   └── card.dart                          # MtgCard & MergedCard models
├── services/
│   ├── scryfall_service.dart             # Scryfall API (offline-first)
│   ├── card_download_service.dart        # Bulk download & import
│   └── database_helper.dart              # SQLite card storage
├── providers/
│   └── card_provider.dart                # State management
├── screens/
│   ├── home_screen.dart                  # Main creature combiner UI
│   └── settings_screen.dart              # Offline cache management
└── widgets/
    └── magic_card_display.dart           # Card display widget
```

## Getting Started

### Prerequisites

- Flutter 3.41.1+
- Dart 3.11.0+ (included with Flutter)
- Android SDK 33+
- Physical Android device or emulator

### Installation & First Run

1. **Get dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on device or emulator:**
   ```bash
   flutter run
   ```

3. **Download creature cache (first time):**
   - Tap ⚙️ Settings icon (top-right)
   - Tap "Download Card Database"
   - Wait for download to complete (~30 seconds on WiFi)

### Build Release APK

```bash
# Generate optimized APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk

# Install on phone:
# 1. Copy APK to phone
# 2. Open file manager
# 3. Tap APK file → Install
# 4. Launch app and download cache
```

## How to Use

### Basic Workflow

1. **Enter a creature name** in the text field (e.g., "Grizzly Bears")
2. **Tap Search** — App checks offline cache first, then API if needed
3. **Card appears below** with stats, type, and abilities
4. **Add more creatures** by repeating steps 1-2
5. **View combined stats** at the bottom:
   - Combined mana value
   - Total power/toughness
   - Merged type line (with supertypes & card types)
   - All unique abilities
6. **Remove a creature** — Tap the X next to its name
7. **Clear all** — Swipe down to reset and start over

### Example: Playing "It Came from Planet Glurg"

You cast "It Came from Planet Glurg" and it copies 3 creatures on the battlefield:
- Grizzly Bears (2/2)
- Elvish Mystic (1/1)
- Scute Swarm (1/1)

1. Open Glurg app
2. Search "Grizzly Bears" → appears as 1G creature
3. Search "Elvish Mystic" → G creature, taps for mana
4. Search "Scute Swarm" → 2G creature with scute landfall ability

**Combined result:**
- **Mana Value**: 5 (1+1+1+2)
- **Power/Toughness**: 4/4 (2+1+1)
- **Type**: Creature — Elf Insect (combined subtypes)
- **Abilities**: All three creatures' abilities merged
- **Card Types**: Shows Legendary/Artifact/Enchantment if any component has it

## API Integration

### Scryfall API Usage

The app uses the **Scryfall fuzzy search** endpoint for card lookup:

```
GET https://api.scryfall.com/cards/named?fuzzy={cardName}
```

**Features:**
- No authentication required (public API)
- Fuzzy matching handles typos and variations
- Returns ~40 card properties including artwork URL
- Rate limit: 100 requests per second (more than enough for this app)

### Example Card Response

```json
{
  "name": "Grizzly Bears",
  "mana_cost": "{1}{G}",
  "mana_value": 2,
  "type_line": "Creature — Bear",
  "power": "2",
  "toughness": "2",
  "oracle_text": "Nothing special, just a bear.",
  "image_uris": {
    "normal": "https://cards.scryfall.io/..."
  }
}
```

## Release Status

**v1.0.0 — RELEASED ✅**

- [x] Core search functionality (Scryfall API)
- [x] Offline mode with SQLite database
- [x] Creature combining & stats merging
- [x] Double-faced card support
- [x] Supertypes & card types display
- [x] Duplicate creature support
- [x] Settings & cache management UI
- [x] Real device testing (Android)
- [x] Release APK build
- [x] Documentation & handoff

**Phase 5: Handoff** — Ready for personal use

## Future Improvements (v2+)

- [ ] **UI Polish** — Improve visual design, spacing, and color scheme
- [ ] **Card Images** — Download artwork for offline viewing
- [ ] **Search Filters** — Filter by type, mana value, power/toughness, abilities
- [ ] **Copy to Clipboard** — Export merged card text for sharing
- [ ] **Dark Mode** — Dark theme option
- [ ] **Camera Scanning** — Scan card names from physical cards with camera
- [ ] **Save Collections** — Save and load card combinations
- [ ] **Stats Export** — Export combined stats to text/image
- [ ] **Search History** — Quick re-access frequently searched cards

## Offline Mode Details

- **Cache Size**: ~4 MB for 50,000+ creature cards
- **Cards Included**: Only creatures with power/toughness
- **Update Method**: Download again in Settings to refresh
- **Performance**: Instant lookups (~0 latency vs ~1 second API)
- **Offline-First**: App prioritizes local cache, falls back to API when online

## Troubleshooting

### "Card not found" error

- Check spelling (fuzzy search catches most typos)
- Try alternative card names (e.g., "Counterspell" vs "Counterspell (5th Edition)")
- Some special characters may need adjustment

### Network errors

- Verify internet connection is working
- Scryfall API is up (check status.scryfall.io)
- Check your device's network settings

### App crashes on startup

- Ensure all dependencies are installed: `flutter pub get`
- Clear build cache: `flutter clean && flutter pub get`
- Rebuild: `flutter run`

## Development Notes

### Adding a New Card Property

1. Update `MtgCard` model in `lib/models/card.dart`
2. Update `MtgCard.fromJson()` to parse the new field from Scryfall
3. Update `CardTile` in `lib/widgets/card_tile.dart` to display it
4. Update `home_screen.dart` if it affects layout

### Testing New Features

```bash
# Run with verbose logging
flutter run -v

# Run tests (if created)
flutter test
```

## Performance Considerations

- **Image Caching**: `cached_network_image` prevents re-downloading artwork
- **Network Requests**: Scryfall is fast (typically <200ms per card)
- **UI Responsiveness**: Provider patterns keep UI responsive during network calls
- **Memory**: Limiting to ~50 cards keeps memory usage minimal

## License

This project is for personal use. Scryfall data is © Scryfall.

## Contact & Support

For issues, questions, or feature requests, check the project notes in `.github/copilot-instructions.md`

