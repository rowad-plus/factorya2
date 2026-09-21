import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shows a spinner while [load] runs, then [builder]; a retry-able message on failure.
class AsyncLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;
  const AsyncLoader({super.key, required this.load, required this.builder});

  @override
  State<AsyncLoader<T>> createState() => _AsyncLoaderState<T>();
}

class _AsyncLoaderState<T> extends State<AsyncLoader<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) return widget.builder(context, snap.data as T);
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(backgroundColor: AppColors.dark, foregroundColor: Colors.white, elevation: 0),
          body: Center(
            child: snap.hasError
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${snap.error}', textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = widget.load()),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                      child: Text('إعادة المحاولة', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ])
                : const CircularProgressIndicator(color: AppColors.gold),
          ),
        );
      },
    );
  }
}
