import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/enhanced_toast.dart';
import 'models/intercom_contact.dart';
import 'models/group_chat_model.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<IntercomContact> availableContacts;
  final String currentUserId;

  const CreateGroupScreen({
    Key? key,
    required this.availableContacts,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<IntercomContact> _selectedContacts = {};
  List<IntercomContact> _filteredContacts = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Initialize filtered contacts
    _filteredContacts = widget.availableContacts.toList();

    // Add current user to selected contacts
    try {
      if (widget.availableContacts.isNotEmpty) {
        // Try to find current user
        final currentUser = widget.availableContacts.firstWhere(
          (contact) => contact.id == widget.currentUserId,
          orElse: () =>
              widget.availableContacts.first, // Fallback to first if not found
        );
        _selectedContacts.add(currentUser);
      } else {
        // Handle empty contacts list
        EnhancedToast.warning(
          context,
          title: 'No Contacts',
          message: 'No contacts available to create a group.',
        );
        // Add a small delay before popping to ensure the Scaffold is built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      // Handle any unexpected errors
      print('Error initializing contacts: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Add a safety helper method for clearing selected contacts
  void _clearSelectedContacts() {
    setState(() {
      try {
        if (_selectedContacts.isNotEmpty) {
          final currentUser = _selectedContacts
              .where((c) => c.id == widget.currentUserId)
              .firstOrNull; // Use firstOrNull for safety

          _selectedContacts.clear();
          if (currentUser != null) {
            _selectedContacts.add(currentUser);
          }
        }
      } catch (e) {
        print('Error clearing contacts: $e');
      }
    });
  }

  // Filter contacts based on search
  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = widget.availableContacts.toList();
      } else {
        _filteredContacts = widget.availableContacts
            .where((contact) =>
                contact.name.toLowerCase().contains(query.toLowerCase()) ||
                (contact.unit != null &&
                    contact.unit!.toLowerCase().contains(query.toLowerCase())))
            .toList();
      }
    });
  }

  bool get _isFormValid {
    // Require at least 2 members (current user + one more) to create a group
    return _nameController.text.trim().isNotEmpty &&
        _selectedContacts.length >= 2;
  }

  Future<void> _createGroup() async {
    // Safety checks before group creation
    if (!_formKey.currentState!.validate() || !_isFormValid) {
      EnhancedToast.warning(
        context,
        title: 'Missing Fields',
        message: 'Please complete all required fields.',
      );
      return;
    }

    // Ensure we have the required minimum contacts
    if (_selectedContacts.length < 2) {
      EnhancedToast.warning(
        context,
        title: 'Members Required',
        message: 'Please select at least 2 contacts for the group.',
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Create new group
    final newGroup = GroupChat(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      creatorId: widget.currentUserId,
      members: _selectedContacts.toList(),
      createdAt: DateTime.now(),
      lastMessageTime: DateTime.now(),
    );

    // Return the new group to the previous screen
    if (mounted) {
      Navigator.pop(context, newGroup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        title: Text(
          'Create Group',
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF4B2B), Color(0xFFFF416C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isFormValid && !_isCreating ? _createGroup : null,
            child: _isCreating
                ? const AppLoader.inline()
                : Text(
                    'CREATE',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF9292)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Background icon for depth effect
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.group,
                        size: 120,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    // Main content
                    Column(
                      children: [
                        // Group icon with animation and elevated effect
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                height: 90,
                                width: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.group_rounded,
                                  size: 45,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Enhanced name field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Group Name',
                              hintStyle: GoogleFonts.montserrat(
                                color: const Color(0xFFB0B0B0),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 16, right: 8),
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: Color(0xFFFF416C),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a group name';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),

                        // Subtitle hint
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Give your group a name your members will recognize',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form content padding
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group description
                    Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: Color(0xFFFF416C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Group Description',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF333333),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Add a description (Optional)',
                          hintStyle: GoogleFonts.montserrat(
                            color: const Color(0xFFB0B0B0),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(18),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Selected members section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.people_alt_outlined,
                              color: Color(0xFFFF416C),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Selected Members (${_selectedContacts.length})',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: const Color(0xFF333333),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedContacts.length > 1)
                          GestureDetector(
                            onTap: _clearSelectedContacts,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF416C).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Clear All',
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFFFF416C),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selected members chips
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedContacts.map((contact) {
                          final isCurrentUser =
                              contact.id == widget.currentUserId;
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: isCurrentUser
                                  ? const Color(0xFFFF416C).withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              child: Text(
                                contact.initials,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentUser
                                      ? const Color(0xFFFF416C)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            label: Text(
                              isCurrentUser
                                  ? 'You (${contact.name})'
                                  : contact.name,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            deleteIcon: isCurrentUser
                                ? null // Don't allow deleting current user
                                : const Icon(Icons.close, size: 16),
                            onDeleted: isCurrentUser
                                ? null
                                : () {
                                    setState(() {
                                      _selectedContacts.remove(contact);
                                    });
                                  },
                            backgroundColor: isCurrentUser
                                ? const Color(0xFFFF416C).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isCurrentUser
                                    ? const Color(0xFFFF416C).withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Available members section
                    Row(
                      children: [
                        const Icon(
                          Icons.person_add_alt_rounded,
                          color: Color(0xFFFF416C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Members',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF333333),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Enhanced search field
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          hintStyle: GoogleFonts.montserrat(
                            color: const Color(0xFFB0B0B0),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: const Color(0xFFFF416C).withOpacity(0.7),
                            size: 20,
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF416C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.mic,
                                color: Color(0xFFFF416C),
                                size: 20,
                              ),
                              onPressed: () {
                                // Voice search functionality would go here
                              },
                              tooltip: 'Voice Search',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: _filterContacts,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Available contacts list
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final isSelected =
                              _selectedContacts.contains(contact);
                          final isCurrentUser =
                              contact.id == widget.currentUserId;

                          if (isCurrentUser) return const SizedBox.shrink();

                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF416C).withOpacity(0.05)
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFFFF416C)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                                top: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFFFF416C)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                                right: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFFFF416C)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                                bottom: BorderSide(
                                  color: index < _filteredContacts.length - 1
                                      ? Colors.grey.shade200
                                      : (isSelected
                                          ? const Color(0xFFFF416C)
                                          : Colors.transparent),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Stack(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF416C)
                                          .withOpacity(0.1),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFF416C)
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        contact.initials,
                                        style: const TextStyle(
                                          color: Color(0xFFFF416C),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (contact.status ==
                                      IntercomContactStatus.online)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                contact.name,
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    contact.type == IntercomContactType.resident
                                        ? Icons.home_outlined
                                        : Icons.badge_outlined,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    contact.type == IntercomContactType.resident
                                        ? 'Flat ${contact.unit}'
                                        : contact.role ?? '',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedContacts.remove(contact);
                                    } else {
                                      _selectedContacts.add(contact);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFFFF416C)
                                        : Colors.grey.shade100,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF416C)
                                                  .withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.add,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
