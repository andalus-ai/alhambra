import 'package:flutter/material.dart';

/// Column descriptor for [AlhambraDataTable].
final class AlhambraDataColumn<T> {
  final String label;
  final Widget Function(T item) cellBuilder;
  final bool numeric;

  const AlhambraDataColumn({
    required this.label,
    required this.cellBuilder,
    this.numeric = false,
  });
}

/// Generic, domain-agnostic data table component.
class AlhambraDataTable<T> extends StatelessWidget {
  final List<T> items;
  final List<AlhambraDataColumn<T>> columns;
  final ValueChanged<T>? onRowTap;

  const AlhambraDataTable({
    super.key,
    required this.items,
    required this.columns,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map(
              (col) => DataColumn(
                label: Text(col.label),
                numeric: col.numeric,
              ),
            )
            .toList(),
        rows: items
            .map(
              (item) => DataRow(
                cells: columns
                    .map(
                      (col) => DataCell(
                        col.cellBuilder(item),
                        onTap: onRowTap != null ? () => onRowTap!(item) : null,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}
