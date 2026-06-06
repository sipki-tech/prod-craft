# Flutter Security
Opinionated, production-ready rules for securing Flutter applications against reverse engineering, MITM attacks, and data leaks.

**Use flutter_secure_storage for sensitive data**
- **Reason:** SharedPreferences and standard local databases store data in plain text, making it trivial to extract on rooted/jailbroken devices. Tokens, PII, and credentials must be encrypted using the platform's secure keystore (Keychain on iOS, Keystore on Android).

```dart
// Good
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = const FlutterSecureStorage();
await storage.write(key: 'session_token', value: token);

// Bad
import 'package:shared_preferences/shared_preferences.dart';

final prefs = await SharedPreferences.getInstance();
await prefs.setString('session_token', token);
```

**Never store private secrets in the client**
- **Reason:** Compiled Flutter apps can be reverse-engineered, and strings are easily extracted. Backend secrets, database passwords, and third-party secret keys must be kept on your server. If the client needs access to a secure service, the server should act as a proxy.

```dart
// Good
class PaymentService {
  // Client calls your backend, which securely holds the Stripe Secret Key
  Future<void> createCharge(int amount) async {
    await apiClient.post('/api/charges', data: {'amount': amount});
  }
}

// Bad
class PaymentService {
  // Secret key is hardcoded and shipped to users
  static const stripeSecret = 'sk_live_12345...'; 
}
```

**Restrict public API keys by origin**
- **Reason:** Some keys (like Firebase or Google Maps) must exist on the client, but they are easily extracted. To prevent quota theft, you must lock these public keys to your specific Android package name, iOS bundle ID, and SHA-1 signing certificates in the provider's console.

```dart
// Good
// Passed via --dart-define and restricted in Google Cloud Console
const mapsApiKey = String.fromEnvironment('MAPS_KEY');

// Bad
// Passed via --dart-define but left unrestricted in the provider console, allowing anyone to use your quota.
const unrestrictedMapsApiKey = String.fromEnvironment('MAPS_KEY');
```

**Obfuscate release builds**
- **Reason:** Dart AOT compilation leaves rich metadata (class names, method names, variable names) intact. Obfuscation renames these symbols, significantly raising the effort required to reverse-engineer business logic.

```shell
# Good
flutter build apk --obfuscate --split-debug-info=build/app/outputs/symbols

# Bad
flutter build apk
```

**Implement certificate pinning for critical APIs**
- **Reason:** Relying solely on the OS trust store leaves the app vulnerable to Man-in-the-Middle (MITM) attacks if a user installs a malicious root CA. Pinning ensures the app only trusts a specific certificate or public key.

```dart
// Good
import 'dart:io';
import 'package:flutter/services.dart';

Future<HttpClient> createPinnedClient() async {
  // Do not trust system roots; only trust our specific certificate
  final context = SecurityContext(withTrustedRoots: false);
  final certBytes = await rootBundle.load('assets/certs/backend.pem');
  context.setTrustedCertificatesBytes(certBytes.buffer.asUint8List());
  
  return HttpClient(context: context);
}

// Bad
// Implicitly trusts any root CA installed on the device
final client = HttpClient();
```
