# Changelog

All notable changes to the Glurg app are documented here.

## [1.0.0] - 2026-02-15

### ✨ Released - Initial Version

**Glurg v1.0 is live!** A fully functional Magic: The Gathering creature combiner for "It Came from Planet Glurg".

### 🎯 Core Features

#### Search & Lookup
- Manual card name search with Scryfall API integration
- Fuzzy matching for typos and partial names
- Search results appear instantly
- Error handling for cards not found

#### Offline Mode
- Download 50,000+ creature cards for offline use
- SQLite database for local storage (~4 MB total)
- Automatic offline-first search (checks cache before API)
- Graceful fallback to API when offline
- Manual download & update in Settings

#### Creature Combining
- Add multiple creatures to combine stats
- Support for duplicate creatures (add same card multiple times)
- Instant stat merging:
  - Combined mana value (sum)
  - Combined power/toughness (sum)
  - Merged type line with supertypes & card types
  - All unique abilities combined

#### Advanced Card Handling
- Double-faced card support with correct face matching
- Supertypes display (Legendary, Snow, Basic, World)
- Card types display (Artifact, Enchantment, Land, etc.)
- Comprehensive type line parsing

#### User Interface
- Material Design 3 with responsive layout
- Settings screen for cache management
- Progress indicator for downloads
- Cache statistics display
- Clear error messages and feedback
- Intuitive card removal (swipe or click X)

### 🔧 Technical Highlights

- **Framework**: Flutter 3.41.1 with Dart 3.11.0
- **State Management**: Provider pattern for responsive updates
- **Database**: SQLite (sqflite) with fuzzy search support
- **API**: Scryfall integration with streaming downloads
- **Performance**: Instant offline lookups, ~1 second API lookups
- **Memory**: Efficient chunk-based processing (1000 cards at a time)
- **Architecture**: Offline-first with graceful API fallback

### 📱 Device Testing

- ✅ Tested on physical Android device
- ✅ Tested on Android emulator (API 36)
- ✅ Tested with internet on (API fallback works)
- ✅ Tested with internet off (offline mode works)
- ✅ Tested duplicate creatures (works as expected)
- ✅ Tested double-faced cards (correct face displays)

### 🐛 Known Issues (Minor)

None reported. App is stable and ready for personal use.

### 📚 Documentation

- Comprehensive README with setup & usage instructions
- Clear project structure documentation
- Troubleshooting guide included
- Code comments for complex logic

---

## Future Versions

### v1.1 (Planned)
- Minor bug fixes and performance tweaks
- Improved error messages
- Additional cache statistics

### v2.0 (Wishlist)
- UI polish and visual improvements
- Card image downloads for offline
- Search filters (by type, mana value, etc.)
- Copy merged card stats to clipboard
- Dark mode support
- Camera-based card scanning
- Save/load card combinations

---

## Development Notes

**Build Time**: From initial concept to v1 release
**Total Features Shipped**: 10+ core features
**Lines of Code**: ~1,500 lines across 10 files
**Test Coverage**: Manual testing on real device ✅
**API Used**: Scryfall (free, no authentication)
**Database**: SQLite with 50,000+ card records

---

## Contributors

- Built with Claude Code + Flutter
- Powered by Scryfall API
- Magic: The Gathering card data © Wizards of the Coast

---

**Ready to use!** Download the APK or build from source.
