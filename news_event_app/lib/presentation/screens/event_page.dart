import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  @override
  void initState() {
    super.initState();
    // Fetch events when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchEvents();
    });
  }

  Future<void> _handleRefresh() async {
    final eventProvider = context.read<EventProvider>();
    await eventProvider.refreshEvents();
    
    // Show error message if refresh failed
    if (mounted && eventProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      eventProvider.clearError();
    }
  }

  void _navigateToCreateEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEventScreen(),
      ),
    );
  }

  void _navigateToEventDetail(String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(eventId: eventId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final eventProvider = context.watch<EventProvider>();
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Builder(
          builder: (context) {
            // Show loading indicator on initial load
            if (eventProvider.isLoading && !eventProvider.hasEvents) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Show empty state when no events available
            if (!eventProvider.hasEvents && !eventProvider.isLoading) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events available',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Sort events with upcoming events first
            final sortedEvents = List.from(eventProvider.eventsList)
              ..sort((a, b) {
                final now = DateTime.now();
                final aIsUpcoming = a.eventDate.isAfter(now);
                final bIsUpcoming = b.eventDate.isAfter(now);
                
                // Upcoming events come first
                if (aIsUpcoming && !bIsUpcoming) return -1;
                if (!aIsUpcoming && bIsUpcoming) return 1;
                
                // Within same category, sort by date (ascending for upcoming, descending for past)
                if (aIsUpcoming) {
                  return a.eventDate.compareTo(b.eventDate);
                } else {
                  return b.eventDate.compareTo(a.eventDate);
                }
              });

            // Show events list
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sortedEvents.length,
              itemBuilder: (context, index) {
                final event = sortedEvents[index];
                return EventCard(
                  event: event,
                  onTap: () => _navigateToEventDetail(event.id),
                );
              },
            );
          },
        ),
      ),
      // Floating action button visible only to admins
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _navigateToCreateEvent,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
