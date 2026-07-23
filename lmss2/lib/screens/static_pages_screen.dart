import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/static_page_model.dart';
import '../providers/static_pages_provider.dart';
import '../widgets/lms_shell.dart';
import '../widgets/static_page_viewer_dialog.dart';

class StaticPagesScreen extends StatefulWidget {
  const StaticPagesScreen({super.key});

  @override
  State<StaticPagesScreen> createState() => _StaticPagesScreenState();
}

class _StaticPagesScreenState extends State<StaticPagesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaticPagesProvider>().fetchPages();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'Manage Static Pages',
      rootPage: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Pages',
          onPressed: () {
            context.read<StaticPagesProvider>().fetchPages();
          },
        ),
      ],
      body: Consumer<StaticPagesProvider>(
        builder: (context, provider, child) {
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
                    onPressed: () => provider.fetchPages(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Filter pages based on search
          final filteredPages = provider.pages.where((p) {
            final query = _searchQuery.toLowerCase();
            return p.title.toLowerCase().contains(query) ||
                p.slug.toLowerCase().contains(query);
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by title or slug...',
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
                        _showAddEditPageDialog(context, null);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Page'),
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
                    child: filteredPages.isEmpty 
                      ? const Center(child: Text('No pages found'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64), 
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade100),
                                columns: const [
                                  DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Slug', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: filteredPages.map((page) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(page.id.toString(), style: const TextStyle(color: Colors.grey))),
                                      DataCell(Text(page.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(page.slug)),
                                      DataCell(_buildStatusBadge(page.isActive)),
                                      DataCell(Text('${page.createdAt.year}-${page.createdAt.month.toString().padLeft(2, '0')}-${page.createdAt.day.toString().padLeft(2, '0')}')),
                                      DataCell(_buildActionButtons(context, page)),
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
        },
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final color = isActive ? Colors.green : Colors.orange;
    final text = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).toInt()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((255 * 0.5).toInt())),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, StaticPageModel page) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Preview Live Page',
          child: IconButton(
            icon: const Icon(Icons.visibility, color: Colors.green),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => StaticPageViewerDialog(page: page),
              );
            },
          ),
        ),
        Tooltip(
          message: 'Edit Page',
          child: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              _showAddEditPageDialog(context, page);
            },
          ),
        ),
        Tooltip(
          message: 'Delete Page',
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              _confirmDelete(context, page);
            },
          ),
        ),
      ],
    );
  }

  void _showAddEditPageDialog(BuildContext context, StaticPageModel? page) {
    final isEditing = page != null;
    final titleController = TextEditingController(text: page?.title ?? '');
    final slugController = TextEditingController(text: page?.slug ?? '');
    final contentController = TextEditingController(text: page?.content ?? '');
    bool isActive = page?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Page' : 'Add New Page'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(
                          labelText: 'Slug',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Content (HTML)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Active Status'),
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            isActive = value;
                          });
                        },
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
                  onPressed: () async {
                    final newPage = StaticPageModel(
                      id: isEditing ? page.id : DateTime.now().millisecondsSinceEpoch, // Mock ID
                      title: titleController.text,
                      slug: slugController.text,
                      content: contentController.text,
                      isActive: isActive,
                      createdAt: isEditing ? page.createdAt : DateTime.now(),
                    );

                    if (isEditing) {
                      await context.read<StaticPagesProvider>().updatePage(newPage);
                    } else {
                      await context.read<StaticPagesProvider>().addPage(newPage);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Page updated' : 'Page created')),
                    );
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Create Page'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, StaticPageModel page) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the page "${page.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await context.read<StaticPagesProvider>().deletePage(page.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Page deleted')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
