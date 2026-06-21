import 'package:flutter/material.dart';

class AboutPageUtil {
  static TableRow getTableRowContent(String tableRowKey, String tableRowValue) {
    return TableRow(
      children: [
        TableCell(
          child: Container(
            padding: const EdgeInsets.only(top: 5.0),
            child: Text(
              tableRowKey,
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        TableCell(
          child: Container(
            padding: const EdgeInsets.only(top: 5.0),
            child: Text(
              tableRowValue,
              style: const TextStyle(fontSize: 12.0),
            ),
          ),
        )
      ],
    );
  }

  static Widget collapsibleSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool initiallyExpanded = false,
    String? trailingLabel,
  }) {
    return _CollapsibleSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      initiallyExpanded: initiallyExpanded,
      trailingLabel: trailingLabel,
      children: children,
    );
  }

  static Widget sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return _StaticSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      children: children,
    );
  }

  static Widget infoTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final String displayValue =
        value.trim().isEmpty ? 'Not captured' : value.trim();
    final bool isEmpty = displayValue == 'Not captured';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w800,
                fontSize: 12.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: isEmpty ? Colors.blueGrey : Colors.black87,
                fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w800,
                fontSize: 12.6,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget statusBanner({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleSectionCard extends StatefulWidget {
  const _CollapsibleSectionCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
    required this.initiallyExpanded,
    this.trailingLabel,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final bool initiallyExpanded;
  final String? trailingLabel;

  @override
  State<_CollapsibleSectionCard> createState() =>
      _CollapsibleSectionCardState();
}

class _CollapsibleSectionCardState extends State<_CollapsibleSectionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(_expanded ? 0.14 : 0.09),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if ((widget.trailingLabel ?? '').trim().isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxWidth: 120),
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.trailingLabel!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12.3,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.children,
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _StaticSectionCard extends StatelessWidget {
  const _StaticSectionCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12.3,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
