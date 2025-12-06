import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;


void main() {
  runApp(const TrustPortApp());
}

// --- THEME ---
const Color kNavy = Color(0xFF000C66);
const Color kTeal = Color(0xFF00897B);
const Color kRed = Color(0xFFD32F2F);
const Color kOrange = Color(0xFFFF9800);
const Color kWhite = Colors.white;
const Color kBgStart = Color(0xFFF5F7FA);
const Color kBgEnd = Color(0xFFE3F2FD);

class TrustPortApp extends StatelessWidget {
  const TrustPortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustPort',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBgStart,
        primaryColor: kNavy,
        textTheme: GoogleFonts.latoTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kNavy,
          secondary: kTeal,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // <--- was DashboardPage()
    );
  }
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;
  bool _initialized = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset('assets/intro.mp4');

    await _controller.initialize();
    if (!mounted) return;

    setState(() => _initialized = true);

    // Web autoplay is more reliable if muted
    // (If you really want sound, you can set this back to 1.0,
    // but muted intro is usually fine.)
    await _controller.setVolume(0.0);
    await _controller.setLooping(false);

    // Listen for video finishing
    _controller.addListener(_checkEnd);

    // Try to play; if browser blocks autoplay, we just show first frame
    try {
      await _controller.play();
    } catch (e) {
      debugPrint('Video play blocked/autoplay issue: $e');
    }

    // Safety fallback: go to dashboard after 15s even if listener never fires
    _fallbackTimer = Timer(const Duration(seconds: 15), _goNextIfNeeded);
  }

  void _checkEnd() {
    final value = _controller.value;
    if (!value.isInitialized) return;

    // 👇 KEY FIX: ignore bogus 0-duration metadata
    if (value.duration == Duration.zero) return;

    if (value.position >= value.duration && !_navigated) {
      _goNextIfNeeded();
    }
  }

  void _goNextIfNeeded() {
    if (!mounted || _navigated) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DashboardPage(),
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.removeListener(_checkEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: VideoPlayer(_controller),
                ),
              )
            : const CircularProgressIndicator(color: kTeal),
      ),
    );
  }
}

// --- DATA MODEL ---
class FinancialData {
  final String originCountry;
  final String currencySymbol;
  final double monthlyIncome;
  final double savingsRate;
  final int riskFlags;
  final int creditScore;
  final int fraudScore;
  final List<double> cashFlow;
  final List<double> predictiveFlow;
  final String riskProfile;
  final List<StatementTransaction> transactions;

  FinancialData({
    required this.originCountry,
    required this.currencySymbol,
    required this.monthlyIncome,
    required this.savingsRate,
    required this.riskFlags,
    required this.creditScore,
    required this.fraudScore,
    required this.cashFlow,
    required this.predictiveFlow,
    required this.riskProfile,
    required this.transactions,
  });

  factory FinancialData.fromJson(Map<String, dynamic> json) {
    final txList = (json['transactions'] as List<dynamic>? ?? []);
    return FinancialData(
      originCountry: json['origin_country'] ?? 'Unknown',
      currencySymbol: json['currency_symbol'] ?? '\$',
      monthlyIncome: (json['monthly_income'] ?? 0).toDouble(),
      savingsRate: (json['savings_rate'] ?? 0).toDouble(),
      riskFlags: json['risk_flags'] ?? 0,
      creditScore:
          (json['creditScore'] ?? json['credit_score'] ?? 0).toInt(),
      fraudScore: (json['fraudScore'] ?? 0).toInt(),
      cashFlow: List<double>.from(
        (json['cashFlow'] ?? []).map((x) => (x as num).toDouble()),
      ),
      predictiveFlow: List<double>.from(
        (json['predictiveFlow'] ?? []).map((x) => (x as num).toDouble()),
      ),
      riskProfile: json['riskProfile'] ?? 'Ready',
      transactions: txList
          .map(
            (e) => StatementTransaction.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  factory FinancialData.initial() {
    return FinancialData(
      originCountry: '---',
      currencySymbol: '\$',
      monthlyIncome: 0,
      savingsRate: 0,
      riskFlags: 0,
      creditScore: 0,
      fraudScore: 0,
      cashFlow: const [],
      predictiveFlow: const [],
      riskProfile: 'Ready',
      transactions: const [],
    );
  }
}

class StatementTransaction {
  final String date;
  final String description;
  final double amount;
  final bool isIncome;
  final String tag;
  final bool isRisky;

  StatementTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.tag,
    required this.isRisky,
  });

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    return StatementTransaction(
      date: json['date'] ?? '',
      description: json['description'] ?? 'Transaction',
      amount: (json['amount'] ?? 0).toDouble(),
      isIncome: (json['is_income'] ??
              json['isIncome'] ??
              false) as bool,
      tag: json['tag'] ?? '',
      isRisky:
          (json['is_risky'] ?? json['isRisk'] ?? false) as bool,
    );
  }
}


// --- BACKEND SERVICE ---
class BackendService {
  static const String baseUrl = "https://trustport-backend-8058.onrender.com";

  static Future<FinancialData> uploadStatement(
      List<int> fileBytes, String filename) async {
    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json is Map<String, dynamic> &&
            json.containsKey('error') &&
            json['error'] == true) {
          throw Exception(json['message']);
        }
        return FinancialData.fromJson(json);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> convertScore(
      FinancialData data, String target) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "origin_country": data.originCountry,
        "currency_symbol": data.currencySymbol,
        "monthly_income": data.monthlyIncome,
        "savings_rate": data.savingsRate,
        "risk_flags": data.riskFlags,
        "creditScore": data.creditScore,
        "target_country": target,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<String> generateLetter(
      String name, int score, String country) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/generate-letter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"name": name, "score": score, "country": country}),
      );
      return jsonDecode(res.body)['letter'];
    } catch (e) {
      return "Failed to generate letter.";
    }
  }
}

// --- DASHBOARD PAGE ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late FinancialData _data;
  Map<String, dynamic>? _convertedData;

  int _selectedIndex = 0;
  String _targetCountry = "Canada";
  String _displayedLetter = "Upload a statement to generate letter.";
  bool _isLoading = false;
  bool _isDownloadingPdf = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _data = FinancialData.initial();
  }

  Future<void> _handleFileUpload() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (res != null && res.files.first.bytes != null) {
      setState(() {
        _isLoading = true;
        _displayedLetter = "Running Vision OCR & Fraud Detection...";
        _convertedData = null;
      });
      try {
        FinancialData newData = await BackendService.uploadStatement(
          res.files.first.bytes!,
          res.files.first.name,
        );
        setState(() {
          _data = newData;
          _isLoading = false;
        });

        // Auto-convert to default target
        _handleConversion(_targetCountry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Analysis complete"),
              backgroundColor: kTeal,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: kRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleConversion(String country) async {
    if (_data.monthlyIncome <= 0) return;
    setState(() {
      _isLoading = true;
      _targetCountry = country;
    });
    try {
      var converted = await BackendService.convertScore(_data, country);
      setState(() {
        _convertedData = converted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateLetter() async {
    if (_convertedData == null) return;
    setState(() {
      _isLoading = true;
      _displayedLetter = "";
    });

    final score =
        (_convertedData!['local_credit_score'] as num?)?.toInt() ?? 0;

    String txt = await BackendService.generateLetter(
      "User",
      score,
      _targetCountry,
    );

    if (mounted) setState(() => _isLoading = false);

    int index = 0;
    _typingTimer?.cancel();
    _typingTimer =
        Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (index < txt.length) {
        if (mounted) {
          setState(() {
            _displayedLetter += txt[index];
          });
        }
        index++;
      } else {
        timer.cancel();
      }
    });
  }

    bool _hasRealLetter() {
      final text = _displayedLetter.trim();
      if (text.isEmpty ||
          text.startsWith("Upload a statement") ||
          text.startsWith("Running Vision")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Generate the AI letter first before downloading."),
            backgroundColor: kRed,
          ),
        );
        return false;
      }
      return true;
    }

    // Download as plain .txt
    void _downloadAsTxt() {
      if (!_hasRealLetter()) return;

      final text = _displayedLetter.trim();

      if (!kIsWeb) {
        // Guard for non-web builds
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "TXT download is currently implemented for web builds only.",
            ),
            backgroundColor: kTeal,
          ),
        );
        return;
      }

      // Flutter Web: create a text file and trigger browser download
      final bytes = utf8.encode(text);
      final blob = html.Blob([bytes], 'text/plain', 'native');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'TrustPort_verification_letter.txt')
        ..click();

      html.Url.revokeObjectUrl(url);
    }

  // Download as a proper PDF with TrustPort logo watermark + header/footer
  Future<void> _downloadAsPdf() async {
    if (!_hasRealLetter()) return;

    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "PDF download is currently implemented for web builds only.",
          ),
          backgroundColor: kTeal,
        ),
      );
      return;
    }

    // Prevent double-click crashes
    if (_isDownloadingPdf) return;

    setState(() {
      _isDownloadingPdf = true;
    });

    try {
      final text = _displayedLetter.trim();

      // TrustPort colours for the PDF
      final pdfNavy  = PdfColor(0 / 255, 12 / 255, 102 / 255);   // #000C66
      final pdfTeal  = PdfColor(0 / 255, 137 / 255, 123 / 255);  // #00897B
      final pdfGrey  = PdfColor(0.35, 0.35, 0.35);
      final pdfLight = PdfColor(0.96, 0.97, 0.99);

      // Load logo (used for header + watermark)
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      final pdf = pw.Document();

      final pageTheme = pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        // BIG, straight watermark in the middle of the page
        buildBackground: logoImage == null
            ? null
            : (context) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.20, // visible but still behind text
                      child: pw.SizedBox(
                        width: 520,  // ⬅️ larger watermark
                        height: 520,
                        child: pw.Image(
                          logoImage!,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,

          // HEADER – bigger logo, same TrustPort colour theme
          header: (context) {
            if (logoImage == null) {
              // Fallback header if logo fails
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TrustPort',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfNavy,
                          ),
                        ),
                        pw.Text(
                          'AI Credit & Risk Profile',
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: pdfTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Divider(color: pdfNavy, thickness: 1),
                  pw.SizedBox(height: 8),
                ],
              );
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  color: pdfLight,
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          // ⬇️ Bigger header logo
                          pw.SizedBox(
                            width: 42,
                            height: 42,
                            child: pw.Image(logoImage!),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            'TrustPort',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: pdfNavy,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'AI Credit & Risk Profile',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: pdfTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(color: pdfNavy, thickness: 0.8),
                pw.SizedBox(height: 8),
              ],
            );
          },

          // FOOTER
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: pdfNavy, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by TrustPort',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: pdfGrey,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: pdfGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // BODY
          build: (context) => [
            pw.Text(
              'Verification Letter',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: 80,
              height: 2.4,
              color: pdfTeal,
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 12,
                height: 1.4,
                color: pdfGrey,
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'TrustPort_verification_letter.pdf')
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to create PDF: $e"),
            backgroundColor: kRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }


    // Show dialog to choose format
    void _showDownloadOptions() {
      if (!_hasRealLetter()) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Download letter as'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _downloadAsPdf();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Text (.txt)'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _downloadAsTxt();
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    Color stateColor = _data.creditScore > 650 ? kTeal : kRed;
    if (_data.creditScore == 0) stateColor = Colors.grey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavy,
        title: Row(
          children: [
            // --- Logo in the app bar ---
            Image.asset(
              'assets/logo.png',
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              "TrustPort",
              style: GoogleFonts.lato(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Optional status pill using stateColor (kept from your old UI)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: stateColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.public,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          _buildSidebar(isMobile),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kBgStart, kBgEnd],
                ),
              ),
              child: _buildBodyContent(stateColor),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBodyContent(Color stateColor) {
    if (_selectedIndex == 0) return _buildDashboardView(stateColor);
    if (_selectedIndex == 1) return _buildTransactionHistoryView(stateColor);
    if (_selectedIndex == 2) return _buildRiskAnalysisView(stateColor);
    return const SizedBox();
  }

  // --- DASHBOARD VIEW ---
  Widget _buildDashboardView(Color stateColor) {
    String incomeDisplay = _convertedData != null
        ? "${_convertedData!['target_currency_symbol']}${_convertedData!['converted_income']}"
        : "${_data.currencySymbol}${_data.monthlyIncome.toStringAsFixed(0)}";

    int targetScore =
        _convertedData != null ? (_convertedData!['local_credit_score'] as num).toInt() : 0;
    double targetMax = _convertedData != null
        ? (_convertedData!['max_score_in_country'] as num).toDouble()
        : 850.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back, User",
                    style: GoogleFonts.lato(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: kNavy,
                    ),
                  ),
                  Text(
                    "Origin detected: ${_data.originCountry} (${_data.currencySymbol}) • Risk: ${_data.riskProfile}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              // Target country dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _targetCountry,
                    icon: const Icon(Icons.flight_takeoff,
                        color: kNavy),
                    items: ["Canada", "USA", "UK", "Germany", "Japan"]
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text("Target: $c"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _handleConversion(v);
                    },
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 40),
          if (_isLoading) const LinearProgressIndicator(color: kTeal),
          const SizedBox(height: 20),

          // Origin vs Target income row (if converted)
          if (_convertedData != null)
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    "Origin: ${_data.originCountry}",
                    "${_data.currencySymbol}${_data.monthlyIncome.toStringAsFixed(0)}",
                    "Original income & score ${_data.creditScore}",
                    Colors.white,
                    Colors.black,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward,
                      color: Colors.grey),
                ),
                Expanded(
                  child: _buildInfoCard(
                    "Target: $_targetCountry",
                    incomeDisplay,
                    "Local score $targetScore / ${targetMax.toInt()}",
                    kTeal.withOpacity(0.1),
                    kTeal,
                  ),
                ),
              ],
            )
          else if (_data.creditScore > 0)
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _scoreGaugeWithLabel(
                  title: "Origin score",
                  score: _data.creditScore,
                  maxScore: 850,
                  subtitle: _data.originCountry,
                ),
                _buildMetricCard(
                  "Monthly Income",
                  incomeDisplay,
                  Icons.account_balance_wallet,
                  stateColor,
                ),
              ],
            ),

          const SizedBox(height: 32),

          // Gauges + metrics
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              if (_convertedData != null) ...[
                _scoreGaugeWithLabel(
                  title: "Origin score",
                  score: _data.creditScore,
                  maxScore: 850,
                  subtitle: _data.originCountry,
                ),
                _scoreGaugeWithLabel(
                  title: "Target score",
                  score: targetScore,
                  maxScore: targetMax,
                  subtitle: _targetCountry,
                ),
              ] else if (_data.creditScore == 0)
                _scoreGaugeWithLabel(
                  title: "Origin score",
                  score: 0,
                  maxScore: 850,
                  subtitle: "Upload a statement to compute.",
                ),
              _buildMetricCard(
                "Savings Rate",
                "${(_data.savingsRate * 100).toStringAsFixed(1)}%",
                Icons.savings,
                stateColor,
              ),
              _buildMetricCard(
                "Fraud Score",
                "${_data.fraudScore}%",
                Icons.policy,
                _data.fraudScore > 20 ? kRed : kTeal,
                isBad: _data.fraudScore > 20,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Cash-flow chart
          Container(
            height: 350,
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cash Flow & 3-Month AI Prediction",
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kNavy,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(child: _buildChart(stateColor)),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (_convertedData != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kNavy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "AI Verification Letter",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _showDownloadOptions,
                            icon: const Icon(Icons.download, color: Colors.white),
                            label: const Text(
                              "Download",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _generateLetter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kTeal,
                              foregroundColor: kNavy,
                            ),
                            child: const Text("Generate Letter"),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 4),
                  const Text(
                    "This letter is AI-generated using Basel III / IFRS 9-style credit "
                    "concepts and FATF-inspired risk indicators, based solely on the "
                    "uploaded statement. It is a high-level informational aid and is not "
                    "legal, regulatory, or credit approval advice.",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _displayedLetter,
                    style: GoogleFonts.lato(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- HISTORY VIEW ---
    Widget _buildTransactionHistoryView(Color stateColor) {
    final txs = _data.transactions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Transaction History",
            style: GoogleFonts.lato(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 20),
          if (txs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _cardDecoration(),
              child: const Text(
                "Upload a bank statement from the sidebar to see parsed "
                "transactions here.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _cardDecoration(),
              child: Column(
                children: txs.map((tx) {
                  final bool isIncome = tx.isIncome;
                  final bool isRisk = tx.isRisky || tx.tag == "Risk Flag";

                  Color avatarBg;
                  IconData icon;
                  if (isRisk) {
                    avatarBg = kRed.withOpacity(0.1);
                    icon = Icons.warning;
                  } else if (isIncome) {
                    avatarBg = kTeal.withOpacity(0.1);
                    icon = Icons.arrow_downward;
                  } else {
                    avatarBg = Colors.grey.withOpacity(0.1);
                    icon = Icons.arrow_upward;
                  }

                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: avatarBg,
                          child: Icon(
                            icon,
                            color: isRisk
                                ? kRed
                                : (isIncome ? kTeal : kNavy),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          tx.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text(tx.date),
                            const SizedBox(width: 8),
                            if (tx.tag.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isRisk
                                      ? kRed.withOpacity(0.1)
                                      : kNavy.withOpacity(0.05),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.tag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isRisk ? kRed : kNavy,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(
                          "${isIncome ? '+' : '-'}"
                          "${_data.currencySymbol}"
                          "${tx.amount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: isIncome
                                ? kTeal
                                : (isRisk ? kRed : kNavy),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(
                          height: 1, color: Colors.black12),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // --- RISK VIEW ---
Widget _buildRiskAnalysisView(Color stateColor) {
  final String analysisNote =
      _convertedData != null ? (_convertedData!['analysis_note'] ?? "") : "";
  final String scoreExplanation = _convertedData != null
      ? (_convertedData!['score_explanation'] ?? "")
      : "";
  final List<dynamic> riskFactorsDynamic =
      _convertedData != null && _convertedData!['risk_factors'] != null
          ? List<dynamic>.from(_convertedData!['risk_factors'])
          : [];
  final List<String> riskFactors =
      riskFactorsDynamic.map((e) => e.toString()).toList();

  return SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Risk Analysis",
          style: GoogleFonts.lato(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: kNavy,
          ),
        ),

        // 🔹 New subtle Basel / IFRS / FATF note under the heading
        const SizedBox(height: 4),
        Text(
          "AI-based assessment using Basel III / IFRS 9-style credit concepts "
          "and FATF-inspired risk screening. High-level only – not legal or "
          "regulatory advice.",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildMetricCard(
              "Fraud Probability",
              "${_data.fraudScore}%",
              Icons.policy,
              _data.fraudScore > 20 ? kRed : kTeal,
              isBad: _data.fraudScore > 20,
            ),
            _buildMetricCard(
              "Income Stability",
              _data.creditScore > 700 ? "98%" : "45%",
              Icons.shield,
              stateColor,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Document Integrity Check (Vision AI)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _data.fraudScore > 20
                    ? "⚠️ Warning: Potential tampering detected by Gemini Vision."
                    : "✅ Passed: No obvious visual artifacts detected.",
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              const Text(
                "Contextual Risk Factors",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (analysisNote.isNotEmpty)
                Text(
                  analysisNote,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              if (scoreExplanation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  scoreExplanation,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              if (riskFactors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: riskFactors
                      .map(
                        (f) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "• ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                f,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
              if (analysisNote.isEmpty &&
                  scoreExplanation.isEmpty &&
                  riskFactors.isEmpty)
                Text(
                  "Upload a statement and select a destination country to see AI-based contextual risk factors.",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
            ],
          ),
        )
      ],
    ),
  );
}


    // --- SIDEBAR & HELPERS ---
  Widget _buildSidebar(bool isMobile) {
    if (isMobile) return const SizedBox.shrink();
    return Container(
      width: 250,
      color: kNavy,
      child: Column(
        children: [
          const SizedBox(height: 32),
        _btn(Icons.dashboard, "Dashboard", 0),
        _btn(Icons.upload_file, "Upload", -1, onTap: _handleFileUpload),
        _btn(Icons.history, "History", 1),
        _btn(Icons.analytics, "Risk", 2),
      ],
    ),
  );
}


  Widget _btn(IconData icon, String label, int idx,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title:
          Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap ??
          () {
            setState(() {
              _selectedIndex = idx;
            });
          },
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNavy.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      );

  // Gauge card with numeric score underneath
  Widget _scoreGaugeWithLabel({
    required String title,
    required int score,
    required double maxScore,
    String? subtitle,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: _buildScoreGauge(score, maxScore),
          ),
          const SizedBox(height: 8),
          Text(
            "${score.toString()} / ${maxScore.toInt()}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kNavy,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreGauge(int score, double maxScore) {
    return SfRadialGauge(
      axes: [
        RadialAxis(
          minimum: 0,
          maximum: maxScore,
          startAngle: 180,
          endAngle: 0,
          showLabels: false,
          showTicks: false,
          axisLineStyle: AxisLineStyle(
            thickness: 0.2,
            thicknessUnit: GaugeSizeUnit.factor,
            color: Colors.grey.shade200,
          ),
          pointers: [
            RangePointer(
              value: score.toDouble(),
              color: kTeal,
              width: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              enableAnimation: true,
            )
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color,
      {bool isBad = false}) {
    return Container(
      width: 200,
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kNavy,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, String sub, Color bg, Color txt) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                color: txt,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: kNavy,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(sub, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildChart(Color color) {
    if (_data.cashFlow.isEmpty) {
      return const Center(child: Text("Upload a statement to see cash flow"));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < _data.cashFlow.length; i++) {
      spots.add(FlSpot(i.toDouble(), _data.cashFlow[i]));
    }

    final predSpots = <FlSpot>[];
    if (_data.predictiveFlow.isNotEmpty) {
      double startX = (spots.length - 1).toDouble();
      predSpots.add(spots.last);
      for (int i = 0; i < _data.predictiveFlow.length; i++) {
        predSpots.add(
          FlSpot(startX + 1 + i.toDouble(), _data.predictiveFlow[i]),
        );
      }
    }

    final allValues = [
      ..._data.cashFlow,
      ..._data.predictiveFlow,
    ];
    double minY = allValues.reduce((a, b) => a < b ? a : b);
    double maxY = allValues.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 100;
      maxY += 100;
    }
    final double padding = (maxY - minY) * 0.1;
    minY -= padding;
    maxY += padding;

    final int totalPoints =
        _data.cashFlow.length + _data.predictiveFlow.length;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.15),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx < 0 || idx >= totalPoints) {
                  return const SizedBox.shrink();
                }
                return Text(
                  "M${idx + 1}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 4,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: predSpots,
            isCurved: true,
            color: kOrange,
            barWidth: 3,
            dashArray: const [5, 5],
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

