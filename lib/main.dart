import 'dart:convert';
import 'dart:io';

import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';

void main() {
  DartNativePluginRegistrant.registerAll();
  SystemChrome.defaultStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF4F7F2),
    systemNavigationBarIconBrightness: Brightness.dark,
  );
  runApp(const MarketScreen());
}

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const symbols = <String, String>{
    'AAPL.US': 'Apple',
    'MSFT.US': 'Microsoft',
    'NVDA.US': 'NVIDIA',
  };
  String symbol = 'AAPL.US';
  List<PricePoint> prices = const [];
  bool loading = true;
  String? error;
  DateTime? updatedAt;

  @override
  void initState() {
    super.initState();
    loadPrices();
  }

  Future<void> loadPrices() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await StockPriceApi.fetchDaily(symbol);
      if (!mounted) return;
      setState(() {
        prices = result;
        updatedAt = DateTime.now();
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  void select(String value) {
    if (symbol == value) return;
    setState(() => symbol = value);
    loadPrices();
  }

  @override
  Widget build(BuildContext context) {
    final latest = prices.isEmpty ? null : prices.last;
    final previous = prices.length < 2 ? null : prices[prices.length - 2];
    final change = latest == null || previous == null
        ? 0.0
        : latest.close - previous.close;
    final percent = previous == null ? 0.0 : change / previous.close * 100;
    final positive = change >= 0;
    final chartWidth = MediaQuery.of(context).size.width - 40;

    return Scaffold(
      brightness: Brightness.light,
      backgroundColor: const Color(0xFFF4F7F2),
      appBar: AppBar(
        title: const Text(
          'Market Glass',
          style: TextStyle(
            color: Color(0xFF172019),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        largeTitle: const Text(
          'Markets',
          style: TextStyle(
            color: Color(0xFF172019),
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        backgroundColor: const Color(0x12F4F7F2),
        actions: [
          GestureDetector(
            onTap: loading ? null : loadPrices,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              child: Text(
                loading ? '•••' : '↻',
                style: const TextStyle(
                  color: Color(0xFF172019),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 88, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SymbolPicker(
              symbols: symbols,
              selected: symbol,
              onSelected: select,
            ),
            const SizedBox(height: 26),
            Text(
              symbols[symbol]!,
              style: const TextStyle(
                color: Color(0xFF637068),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latest == null ? '—' : '\$${latest.close.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF172019),
                    fontSize: 43,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                    height: 1.05,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                if (latest != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: positive
                          ? const Color(0xFFE1F4E7)
                          : const Color(0xFFFBE3DF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${positive ? '+' : ''}${percent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: positive
                            ? const Color(0xFF167142)
                            : const Color(0xFFA73B31),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              latest == null
                  ? '最新の市場データを取得中'
                  : '${positive ? '+' : ''}\$${change.toStringAsFixed(2)}  ·  ${latest.date.month}/${latest.date.day} 終値',
              style: const TextStyle(
                color: Color(0xFF77827B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 26),
            MarketPanel(
              width: chartWidth,
              prices: prices,
              loading: loading,
              error: error,
              onRetry: loadPrices,
            ),
            const SizedBox(height: 18),
            if (latest != null) StatsPanel(latest: latest),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'YAHOO FINANCE · DAILY',
                  style: TextStyle(
                    color: Color(0xFF8A948D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  updatedAt == null
                      ? '未更新'
                      : '${two(updatedAt!.hour)}:${two(updatedAt!.minute)} 更新',
                  style: const TextStyle(
                    color: Color(0xFF8A948D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SymbolPicker extends StatelessWidget {
  const SymbolPicker({
    super.key,
    required this.symbols,
    required this.selected,
    required this.onSelected,
  });
  final Map<String, String> symbols;
  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) => GlassEffectGroup(
    spacing: 10,
    child: Row(
      children: symbols.keys.map((item) {
        final active = selected == item;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(item),
            child: GlassEffectContainer(
              interactive: true,
              borderRadius: BorderRadius.circular(18),
              tint: active ? const Color(0xB8172019) : const Color(0x30FFFFFF),
              shadow: active
                  ? const BoxShadow(
                      color: Color(0x24172019),
                      offset: Offset(0, 5),
                      blurRadius: 14,
                    )
                  : null,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xE8172019)
                      : const Color(0x80FFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: active
                        ? const Color(0x00172019)
                        : const Color(0xB8FFFFFF),
                  ),
                ),
                child: Text(
                  item.split('.').first,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFFF8FBF7)
                        : const Color(0xFF59645D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class MarketPanel extends StatelessWidget {
  const MarketPanel({
    super.key,
    required this.width,
    required this.prices,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final double width;
  final List<PricePoint> prices;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF18231C),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30172019),
          offset: Offset(0, 16),
          blurRadius: 34,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '30 sessions',
                style: TextStyle(
                  color: Color(0xFFB8C5BC),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3930),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '1M',
                  style: TextStyle(
                    color: Color(0xFFE4FF74),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (loading && prices.isEmpty)
          const SizedBox(
            height: 214,
            child: Center(
              child: Text(
                '市場に接続しています…',
                style: TextStyle(color: Color(0xFFB8C5BC), fontSize: 14),
              ),
            ),
          )
        else if (error != null && prices.isEmpty)
          Container(
            height: 214,
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'データを取得できませんでした',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF2F6F2),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF93A198),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onRetry,
                  child: const Text(
                    'もう一度試す  →',
                    style: TextStyle(
                      color: Color(0xFFE4FF74),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          CustomPaint(
            size: Size(width, 214),
            painter: PriceChartPainter(prices),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 9, 22, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('4 weeks ago', style: chartLabelStyle),
              Text('Today', style: chartLabelStyle),
            ],
          ),
        ),
      ],
    ),
  );
}

const chartLabelStyle = TextStyle(
  color: Color(0xFF77877D),
  fontSize: 11,
  fontWeight: FontWeight.w500,
);

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key, required this.latest});
  final PricePoint latest;

  @override
  Widget build(BuildContext context) => GlassEffectContainer(
    borderRadius: BorderRadius.circular(26),
    tint: const Color(0x22FFFFFF),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xA6FFFFFF),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xD8FFFFFF)),
      ),
      child: Column(
        children: [
          StatRow(
            label: 'Day range',
            value:
                '\$${latest.low.toStringAsFixed(2)}  —  \$${latest.high.toStringAsFixed(2)}',
          ),
          const Divider(height: 25, color: Color(0x1F172019)),
          StatRow(label: 'Open', value: '\$${latest.open.toStringAsFixed(2)}'),
          const Divider(height: 25, color: Color(0x1F172019)),
          StatRow(label: 'Volume', value: compactVolume(latest.volume)),
        ],
      ),
    ),
  );
}

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6C776F),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF202922),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class PriceChartPainter extends CustomPainter {
  const PriceChartPainter(this.prices);
  final List<PricePoint> prices;

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;
    const xPad = 22.0;
    const yPad = 16.0;
    final values = prices.map((point) => point.close).toList();
    var minimum = values.first;
    var maximum = values.first;
    for (final value in values.skip(1)) {
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }
    final span = maximum == minimum ? 1.0 : maximum - minimum;
    final chartWidth = size.width - xPad * 2;
    final chartHeight = size.height - yPad * 2;
    final grid = Paint(color: const Color(0x1FFFFFFF), strokeWidth: 1);
    for (var index = 1; index < 4; index++) {
      final y = yPad + chartHeight * index / 4;
      canvas.drawLine(Offset(xPad, y), Offset(size.width - xPad, y), grid);
    }
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = xPad + chartWidth * index / (values.length - 1);
      final y = yPad + (maximum - values[index]) / span * chartHeight;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint(
        color: const Color(0xFFE4FF74),
        style: PaintingStyle.stroke,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    );
    final y = yPad + (maximum - values.last) / span * chartHeight;
    final end = Offset(size.width - xPad, y);
    canvas.drawCircle(end, 7, Paint(color: const Color(0x40172019)));
    canvas.drawCircle(end, 4, Paint(color: const Color(0xFFE4FF74)));
  }

  @override
  bool shouldRepaint(covariant PriceChartPainter oldDelegate) =>
      oldDelegate.prices != prices;
}

class StockPriceApi {
  static Future<List<PricePoint>> fetchDaily(String symbol) async {
    final ticker = symbol.split('.').first;
    final uri = Uri.https(
      'query1.finance.yahoo.com',
      '/v8/finance/chart/$ticker',
      {'range': '1mo', 'interval': '1d', 'events': 'history'},
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'MarketGlass/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('API returned HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final root = jsonDecode(body) as Map<String, dynamic>;
      final chart = root['chart'] as Map<String, dynamic>;
      if (chart['error'] != null) {
        throw Exception('株価APIからエラーが返されました');
      }
      final results = chart['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw Exception('この銘柄の価格データがありません');
      }
      final data = results.first as Map<String, dynamic>;
      final timestamps = data['timestamp'] as List<dynamic>? ?? const [];
      final indicators = data['indicators'] as Map<String, dynamic>;
      final quotes = indicators['quote'] as List<dynamic>?;
      if (quotes == null || quotes.isEmpty) {
        throw Exception('価格データがありません');
      }
      final quote = quotes.first as Map<String, dynamic>;
      final opens = quote['open'] as List<dynamic>? ?? const [];
      final highs = quote['high'] as List<dynamic>? ?? const [];
      final lows = quote['low'] as List<dynamic>? ?? const [];
      final closes = quote['close'] as List<dynamic>? ?? const [];
      final volumes = quote['volume'] as List<dynamic>? ?? const [];
      final result = <PricePoint>[];
      for (var index = 0; index < timestamps.length; index++) {
        if (index >= opens.length ||
            index >= highs.length ||
            index >= lows.length ||
            index >= closes.length ||
            closes[index] == null) {
          continue;
        }
        result.add(
          PricePoint(
            date: DateTime.fromMillisecondsSinceEpoch(
              (timestamps[index] as num).toInt() * 1000,
            ),
            open:
                (opens[index] as num?)?.toDouble() ??
                (closes[index] as num).toDouble(),
            high:
                (highs[index] as num?)?.toDouble() ??
                (closes[index] as num).toDouble(),
            low:
                (lows[index] as num?)?.toDouble() ??
                (closes[index] as num).toDouble(),
            close: (closes[index] as num).toDouble(),
            volume: index < volumes.length
                ? (volumes[index] as num?)?.toInt() ?? 0
                : 0,
          ),
        );
      }
      if (result.length < 2) throw Exception('価格データが不足しています');
      return result.length > 30 ? result.sublist(result.length - 30) : result;
    } finally {
      client.close(force: true);
    }
  }
}

class PricePoint {
  const PricePoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
}

String two(int value) => value.toString().padLeft(2, '0');
String compactVolume(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
