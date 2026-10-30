import 'package:flutter/material.dart';
import '../../../core/theme/theme_redesign.dart';

/// Shared redesign bottom-sheet scaffold for the admin role.
/// Navy→teal gradient, top-rounded, drag handle + close button, scrollable.
/// Mirrors the trainer `_RedesignSheet`. Open with:
///   showModalBottomSheet(isScrollControlled: true, backgroundColor:
///   Colors.transparent, builder: (_) => AdminRedesignSheet(children: [...]))
class AdminRedesignSheet extends StatelessWidget {
  final List<Widget> children;

  const AdminRedesignSheet({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RedesignColors.primario900, RedesignColors.secundario900],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: RedesignColors.primario300,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
