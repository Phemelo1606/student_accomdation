// widgets/search_filter_widgets.dart
import 'package:flutter/material.dart';
import 'package:student_accomdation/core/searchFilter.dart';

class SearchBarWithFilters extends StatefulWidget {
  final SearchFilters initialFilters;
  final ValueChanged<SearchFilters> onFiltersChanged;
  final Map<String, List<String>> filterOptions;

  const SearchBarWithFilters({
    super.key,
    required this.initialFilters,
    required this.onFiltersChanged,
    required this.filterOptions,
  });

  @override
  State<SearchBarWithFilters> createState() => _SearchBarWithFiltersState();
}

class _SearchBarWithFiltersState extends State<SearchBarWithFilters> {
  final TextEditingController _searchController = TextEditingController();
  late SearchFilters _filters;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _searchController.text = _filters.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilters(SearchFilters newFilters) {
    setState(() {
      _filters = newFilters;
    });
    widget.onFiltersChanged(newFilters);
  }

  void _applySearch() {
    _updateFilters(
        _filters.copyWith(searchQuery: _searchController.text.trim()));
  }

  void _clearFilters() {
    _searchController.clear();
    _updateFilters(const SearchFilters());
    setState(() {
      _showFilters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search rooms by location, type, or price",
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _updateFilters(_filters.copyWith(searchQuery: ''));
                    }
                  },
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              IconButton(
                onPressed: _applySearch,
                icon: const Icon(Icons.search, color: Colors.black),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _showFilters ? const Color(0xFF1A168C) : Colors.black,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Filter Panel
        _buildFilterPanel(),

        // Active Filters Indicator
        if (_filters.hasActiveFilters) _buildActiveFiltersIndicator(),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showFilters ? 280 : 0,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Location Filter
              _buildFilterDropdown(
                label: 'Location',
                value: _filters.location,
                items: widget.filterOptions['locations'] ?? ['All'],
                onChanged: (value) {
                  _updateFilters(_filters.copyWith(location: value!));
                },
              ),

              const SizedBox(height: 16),

              // Room Type Filter
              _buildFilterDropdown(
                label: 'Room Type',
                value: _filters.roomType,
                items: widget.filterOptions['roomTypes'] ?? ['All'],
                onChanged: (value) {
                  _updateFilters(_filters.copyWith(roomType: value!));
                },
              ),

              const SizedBox(height: 16),

              // Price Range Filter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Range: R${_filters.minPrice.toInt()} - R${_filters.maxPrice.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: RangeValues(_filters.minPrice, _filters.maxPrice),
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels(
                      'R${_filters.minPrice.toInt()}',
                      'R${_filters.maxPrice.toInt()}',
                    ),
                    onChanged: (values) {
                      _updateFilters(_filters.copyWith(
                        minPrice: values.start,
                        maxPrice: values.end,
                      ));
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Filter Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear Filters'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showFilters = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A168C),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Active filters:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_filters.searchQuery.isNotEmpty)
                  _buildFilterChip('Search: "${_filters.searchQuery}"'),
                if (_filters.location != 'All')
                  _buildFilterChip('Location: ${_filters.location}'),
                if (_filters.roomType != 'All')
                  _buildFilterChip('Type: ${_filters.roomType}'),
                _buildFilterChip(
                    'Price: R${_filters.minPrice.toInt()}-R${_filters.maxPrice.toInt()}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: const Color(0xFF1A168C).withOpacity(0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
