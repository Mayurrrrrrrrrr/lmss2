import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/store_model.dart';
import '../providers/stores_provider.dart';
import '../widgets/lms_shell.dart';
import '../theme/lms_theme.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoresProvider>().fetchStores();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.sizeOf(context).width >= LmsBreakpoints.desktop;

    return LmsShell(
      title: 'Manage Stores',
      rootPage: true,
      body: Consumer<StoresProvider>(
        builder: (context, provider, child) {
          return _buildMainContent(context, provider, isDesktop);
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, StoresProvider provider, bool isDesktop) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.fetchStores(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Filter based on search
    final filtered = provider.stores.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.storeName.toLowerCase().contains(query) ||
          (item.storeCode != null && item.storeCode!.toLowerCase().contains(query));
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Manage Stores',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Stores',
                  onPressed: () => provider.fetchStores(),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Header & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search stores...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          }
                        ) 
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _showAddEditDialog(context, null);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Store'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Data Table
          Expanded(
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: filtered.isEmpty 
                ? const Center(child: Text('No stores found'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - (isDesktop ? 300 : 32)),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade100),
                          columns: const [
                            DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Store Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Store Code', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.id.toString(), style: const TextStyle(color: Colors.grey))),
                                DataCell(Text(item.storeName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(item.storeCode ?? '—')),
                                DataCell(Text(item.location ?? '—')),
                                DataCell(_buildActionButtons(context, item)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, StoreModel item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Edit',
          child: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              _showAddEditDialog(context, item);
            },
          ),
        ),
        Tooltip(
          message: 'Delete',
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              _confirmDelete(context, item);
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, StoreModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Store'),
        content: Text('Are you sure you want to delete ${item.storeName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              context.read<StoresProvider>().deleteStore(item.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.storeName} deleted')),
              );
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, StoreModel? item) {
    final nameController = TextEditingController(text: item?.storeName);
    final codeController = TextEditingController(text: item?.storeCode);
    final locationController = TextEditingController(text: item?.location);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add New Store' : 'Edit Store'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Store Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Store Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(item == null ? 'Store added successfully' : 'Store updated successfully')),
              );
            },
            child: Text(item == null ? 'Add Store' : 'Save Changes'),
          ),
        ],
      ),
    );
  }
}
