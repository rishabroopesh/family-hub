"""
Seed realistic high-school course data plus a busy student's after-school life
for the demo.

Idempotent: synthetic google_course_id values prefixed with "seed-" mean the
real Google Classroom sync (which keys on google_course_id) will never touch
or remove these rows. Run multiple times safely.

Manual calendar events use a "demo:" prefix in their description so they can
be cleaned up on re-seed.

Usage:
    python manage.py seed_demo_data <username>
    python manage.py seed_demo_data <username> --clear   # wipe existing seed first
"""
import datetime
import logging

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import GoogleCredential
from apps.calendar_app.models import CalendarEvent
from apps.classroom.models import Course, Coursework
from apps.workspaces.models import Workspace

logger = logging.getLogger(__name__)
User = get_user_model()

SEED_PREFIX = "seed-"
DEMO_EVENT_MARKER = "demo-seed"  # placed in description so we can clean up


# ============================================================
# Course catalog: 6 classes representing a full daily schedule
# ============================================================
COURSES = [
    (
        "chem-101",
        "AP Chemistry",
        "Period 1",
        "Dr. Patel",
        "Room 214",
        "Advanced placement chemistry covering atomic structure, bonding, thermodynamics, and equilibrium.",
    ),
    (
        "calc-bc",
        "AP Calculus BC",
        "Period 2",
        "Ms. Rodriguez",
        "Room 305",
        "Differential and integral calculus with sequences, series, and parametric equations.",
    ),
    (
        "eng-lit",
        "English Literature",
        "Period 3",
        "Mr. Kowalski",
        "Room 118",
        "Survey of American and British literature from the 19th century to present.",
    ),
    (
        "us-hist",
        "U.S. History",
        "Period 5",
        "Ms. Bennett",
        "Room 221",
        "American history from colonial period through the modern era, with emphasis on primary sources.",
    ),
    (
        "spanish-3",
        "Spanish 3",
        "Period 6",
        "Sra. Morales",
        "Room 142",
        "Intermediate Spanish focused on conversational fluency, advanced grammar, and Latin American culture.",
    ),
    (
        "cs-intro",
        "Intro to Computer Science",
        "Period 7",
        "Mr. Tanaka",
        "Room 410 (Lab)",
        "Introduction to programming in Java. Covers variables, control flow, methods, classes, and basic data structures.",
    ),
]


# ============================================================
# Coursework: ~14 items per course, spread across 14 days
# Format: (course_sid, item_sid, title, description, work_type, max_points, days_from_now, hour)
# ============================================================
COURSEWORK = [
    # ----- AP Chemistry -----
    ("chem-101", "cw-1", "Chapter 7 Problem Set", "Complete problems 7.1-7.24 from the textbook. Show all work for credit. We will go over the toughest ones in class on Wednesday.", "ASSIGNMENT", 25, 0, 23),
    ("chem-101", "cw-2", "Lab Report: Stoichiometry", "Write a full lab report on Tuesday's stoichiometry experiment. Include data tables, calculations, and a discussion of error sources. Minimum 3 pages.", "ASSIGNMENT", 50, 2, 23),
    ("chem-101", "cw-3", "Quiz: Chemical Bonding", "In-class quiz covering ionic, covalent, and metallic bonding. Bring a calculator. 20 minutes.", "ASSIGNMENT", 30, 4, 9),
    ("chem-101", "cw-4", "Reading: Chapter 8 Sections 1-3", "Read the assigned sections and answer the reading guide questions on Google Classroom. Be ready to discuss intermolecular forces in class.", "ASSIGNMENT", 15, 1, 23),
    ("chem-101", "cw-5", "Pre-lab: Acid-Base Titration", "Complete the pre-lab worksheet before Thursday's lab. Calculate the expected molarity for each titration. You will not be allowed to start the lab without this.", "ASSIGNMENT", 20, 3, 8),
    ("chem-101", "cw-6", "Mole Conversion Practice", "20-question worksheet on mole-to-gram and mole-to-particle conversions. This will be on the unit exam.", "ASSIGNMENT", 20, 6, 23),
    ("chem-101", "cw-7", "Unit 5 Exam: Thermochemistry", "Comprehensive exam on enthalpy, calorimetry, Hess's law, and bond energies. Review the practice problems and last week's lab. Worth 15% of your quarter grade.", "ASSIGNMENT", 100, 8, 9),
    ("chem-101", "cw-8", "Lab Report: Acid-Base Titration", "Lab report from Thursday's titration. Include your titration curves and discuss sources of error.", "ASSIGNMENT", 50, 9, 23),
    ("chem-101", "cw-9", "Online Practice: Equilibrium", "Complete the 25-question online practice set on chemical equilibrium. You can retake it as many times as you need.", "ASSIGNMENT", 15, 11, 23),
    ("chem-101", "cw-10", "Project Proposal: Independent Lab", "Submit a one-page proposal for your independent lab project. Include your hypothesis, materials, and procedure.", "ASSIGNMENT", 30, 13, 23),
    ("chem-101", "cw-11", "Quiz: Equilibrium and Le Chatelier", "Short quiz on equilibrium constants and Le Chatelier's principle.", "ASSIGNMENT", 25, 12, 9),

    # ----- AP Calculus BC -----
    ("calc-bc", "cw-1", "Section 6.3 Homework", "Problems 1-25 odd. Focus on integration by parts and partial fractions.", "ASSIGNMENT", 20, 0, 23),
    ("calc-bc", "cw-2", "Quiz: Integration Techniques", "10-question quiz on u-substitution, integration by parts, and trig substitution. No calculator.", "ASSIGNMENT", 25, 2, 9),
    ("calc-bc", "cw-3", "Section 6.4 Homework", "Problems 1-20 even. Trig substitution practice.", "ASSIGNMENT", 20, 1, 23),
    ("calc-bc", "cw-4", "Series Convergence Worksheet", "Practice problems for ratio test, root test, and integral test. Show all work and state which test you used.", "ASSIGNMENT", 30, 5, 23),
    ("calc-bc", "cw-5", "Section 7.1 Homework", "Problems 1-30. Introduction to infinite sequences.", "ASSIGNMENT", 20, 3, 23),
    ("calc-bc", "cw-6", "Midterm Exam Review Packet", "Complete the 40-problem review packet in preparation for next week's midterm. We will go over it in class on Monday.", "ASSIGNMENT", 40, 7, 23),
    ("calc-bc", "cw-7", "Midterm Exam: Integration & Series", "Cumulative exam covering all integration techniques, infinite series, and convergence tests. Bring a graphing calculator. 90 minutes.", "ASSIGNMENT", 100, 10, 9),
    ("calc-bc", "cw-8", "Polar Coordinates Practice", "Convert between polar and Cartesian, find areas in polar coordinates. Problems 1-20.", "ASSIGNMENT", 20, 4, 23),
    ("calc-bc", "cw-9", "Section 8.1 Homework", "Parametric equations problems 1-15.", "ASSIGNMENT", 20, 12, 23),
    ("calc-bc", "cw-10", "Quiz: Polar & Parametric", "Short quiz covering polar coordinates and parametric equations.", "ASSIGNMENT", 25, 13, 9),
    ("calc-bc", "cw-11", "AP Practice Test", "Take the practice AP exam at home and bring your answers Monday. Time yourself: 1 hour 45 minutes for the multiple choice.", "ASSIGNMENT", 50, 11, 23),

    # ----- English Literature -----
    ("eng-lit", "cw-1", "Read: The Great Gatsby Chapters 1-3", "Read the first three chapters and answer the discussion questions on the class blog. Pay attention to the introduction of Nick as narrator.", "ASSIGNMENT", 15, 1, 23),
    ("eng-lit", "cw-2", "Reading Journal: Gatsby Week 1", "Write a 1-page reading journal reflecting on the first three chapters. What questions do you have? What surprised you?", "ASSIGNMENT", 20, 2, 23),
    ("eng-lit", "cw-3", "Vocabulary Quiz: Unit 4", "20-word quiz on this week's vocabulary list. Be ready to use each word in a sentence.", "ASSIGNMENT", 20, 3, 9),
    ("eng-lit", "cw-4", "Read: Gatsby Chapters 4-6", "Continue reading and bring annotated copies to Thursday's discussion.", "ASSIGNMENT", 15, 5, 23),
    ("eng-lit", "cw-5", "Essay Outline: Symbolism in Gatsby", "Submit an outline for your symbolism essay. Include your thesis statement and three main points with textual evidence.", "ASSIGNMENT", 25, 4, 23),
    ("eng-lit", "cw-6", "In-Class Writing: Author's Tone", "Short response essay on F. Scott Fitzgerald's narrative voice. 1-2 pages, written in class.", "ASSIGNMENT", 25, 6, 14),
    ("eng-lit", "cw-7", "Essay Draft: Symbolism in Gatsby", "First draft of your 4-page essay analyzing symbolism in The Great Gatsby. Use at least three direct quotes from the text.", "ASSIGNMENT", 50, 8, 23),
    ("eng-lit", "cw-8", "Read: Gatsby Chapters 7-9", "Finish the novel. We will discuss the ending and Fitzgerald's final imagery on Monday.", "ASSIGNMENT", 15, 9, 23),
    ("eng-lit", "cw-9", "Peer Review Workshop", "Bring two printed copies of your essay draft for in-class peer review. You will exchange with two classmates.", "ASSIGNMENT", 20, 10, 14),
    ("eng-lit", "cw-10", "Final Essay: Symbolism in Gatsby", "Final 4-page essay incorporating peer feedback and the rubric criteria. Submit through Google Classroom.", "ASSIGNMENT", 100, 13, 23),
    ("eng-lit", "cw-11", "Vocabulary Quiz: Unit 5", "20-word vocab quiz. Same format as last week.", "ASSIGNMENT", 20, 11, 9),

    # ----- U.S. History -----
    ("us-hist", "cw-1", "Reading: Reconstruction Era", "Read pages 412-438 and complete the chapter outline. We will use it for Thursday's Socratic seminar.", "ASSIGNMENT", 20, 1, 23),
    ("us-hist", "cw-2", "Primary Source Analysis: Frederick Douglass", "Read the assigned letter from Frederick Douglass and answer the analysis questions. Focus on his rhetorical strategies.", "ASSIGNMENT", 25, 3, 23),
    ("us-hist", "cw-3", "Socratic Seminar: Reconstruction", "Come to class prepared to discuss the political, social, and economic outcomes of Reconstruction. Bring three discussion questions.", "ASSIGNMENT", 30, 4, 9),
    ("us-hist", "cw-4", "DBQ Practice: Industrial Revolution", "Complete the document-based question using the four primary sources provided. Use the AP DBQ rubric.", "ASSIGNMENT", 50, 6, 23),
    ("us-hist", "cw-5", "Unit Test: Gilded Age", "Multiple choice and short answer test covering 1865-1900. Includes questions on industrialization, immigration, and labor movements.", "ASSIGNMENT", 100, 9, 9),
    ("us-hist", "cw-6", "Reading: Progressive Era", "Read pages 462-489. Pay attention to the muckrakers and the major reforms of the early 1900s.", "ASSIGNMENT", 20, 10, 23),
    ("us-hist", "cw-7", "Group Project: Progressive Reform Movement", "In groups of 3, prepare a 10-minute presentation on a Progressive Era reform movement. Sign up sheet posted on Google Classroom.", "ASSIGNMENT", 75, 12, 23),
    ("us-hist", "cw-8", "Map Quiz: WWI Europe", "Identify European countries and major battle sites pre-WWI. Study the handout from Tuesday.", "ASSIGNMENT", 20, 13, 9),
    ("us-hist", "cw-9", "Document Analysis: Roosevelt's Square Deal", "Analyze two primary sources on Theodore Roosevelt's domestic policy. Answer the four guided questions.", "ASSIGNMENT", 25, 7, 23),

    # ----- Spanish 3 -----
    ("spanish-3", "cw-1", "Vocabulario: Capítulo 5", "Memorize this week's vocabulary list. Quiz on Friday.", "ASSIGNMENT", 15, 4, 9),
    ("spanish-3", "cw-2", "Composición: Mi Familia", "Write a one-page composition in Spanish describing your family. Use at least 5 vocabulary words from this unit.", "ASSIGNMENT", 30, 2, 23),
    ("spanish-3", "cw-3", "Conjugación: Subjuntivo", "Practice worksheet on the present subjunctive. Conjugate 30 verbs and use each in a sentence.", "ASSIGNMENT", 25, 5, 23),
    ("spanish-3", "cw-4", "Lectura: Capítulo 5", "Read the assigned story and answer the comprehension questions in Spanish.", "ASSIGNMENT", 20, 1, 23),
    ("spanish-3", "cw-5", "Examen Oral", "Oral exam — 5-minute conversation with the teacher in Spanish. Topics will be drawn from this unit's reading. Practice with a partner!", "ASSIGNMENT", 50, 11, 9),
    ("spanish-3", "cw-6", "Cultural Project: Latin American Country", "Create a one-page infographic about a Latin American country of your choice. Include geography, culture, food, and one interesting fact.", "ASSIGNMENT", 40, 8, 23),
    ("spanish-3", "cw-7", "Vocabulario: Capítulo 6", "New vocabulary list for the next chapter. Quiz next Friday.", "ASSIGNMENT", 15, 9, 9),
    ("spanish-3", "cw-8", "Escritura: Carta Formal", "Write a formal letter in Spanish to a hypothetical Latin American university requesting information about studying abroad.", "ASSIGNMENT", 35, 12, 23),
    ("spanish-3", "cw-9", "Quiz: Subjunctive", "Quiz on the present subjunctive forms and usage.", "ASSIGNMENT", 25, 6, 9),

    # ----- Intro to CS -----
    ("cs-intro", "cw-1", "Lab 4: Loops and Iteration", "Write a Java program that prints the Fibonacci sequence up to a user-specified limit. Submit your .java file on Google Classroom.", "ASSIGNMENT", 30, 1, 23),
    ("cs-intro", "cw-2", "Reading: Chapter 5 - Methods", "Read Chapter 5 in the textbook. Be ready to discuss method parameters, return values, and scope on Wednesday.", "ASSIGNMENT", 10, 2, 23),
    ("cs-intro", "cw-3", "Lab 5: Methods Practice", "Refactor your Lab 4 program to use methods. Each method should do one thing well.", "ASSIGNMENT", 30, 4, 23),
    ("cs-intro", "cw-4", "Quiz: Methods and Scope", "Short quiz on methods, parameters, return types, and variable scope.", "ASSIGNMENT", 25, 6, 9),
    ("cs-intro", "cw-5", "Lab 6: Arrays Introduction", "Write a Java program that reads 10 numbers into an array, then prints the min, max, and average.", "ASSIGNMENT", 35, 8, 23),
    ("cs-intro", "cw-6", "Project Proposal: Mini-Game", "Submit a one-page proposal for your end-of-semester mini-game project. Describe what your game does, what classes you'll need, and any libraries.", "ASSIGNMENT", 25, 10, 23),
    ("cs-intro", "cw-7", "Reading: Chapter 6 - Arrays", "Read Chapter 6 sections 1-4. Focus on array initialization, indexing, and the enhanced for loop.", "ASSIGNMENT", 10, 5, 23),
    ("cs-intro", "cw-8", "Lab 7: Array Algorithms", "Implement linear search and bubble sort on an array of integers. Compare the runtimes.", "ASSIGNMENT", 40, 11, 23),
    ("cs-intro", "cw-9", "Midterm Exam", "In-class midterm exam covering variables, control flow, methods, arrays. 60 minutes. Closed book but you can bring a one-page reference sheet.", "ASSIGNMENT", 100, 13, 9),
    ("cs-intro", "cw-10", "Code Review: Partner Lab", "Pair up with a classmate and review each other's Lab 7 submissions. Submit a written code review with at least three constructive comments.", "ASSIGNMENT", 20, 12, 23),
]


# ============================================================
# Manual calendar events: after-school life
# Format: (title, description, days_from_now, start_hour, start_min, duration_hours, all_day)
# Recurring events expand below.
# ============================================================
ONE_OFF_EVENTS = [
    ("Volleyball Tournament", "Saturday tournament at Eastside Gym. First match at 9 AM, expect 3-4 games. Bring knee pads and two water bottles.", 5, 9, 0, 5, False),
    ("College Essay Workshop", "Optional workshop run by Mrs. Chen in the library. Bring your Common App essay draft.", 6, 10, 0, 2, False),
    ("Parent-Teacher Conference", "Mom is meeting with Mr. Kowalski about the literature midterm. Be home by 6 PM.", 8, 17, 30, 1, False),
    ("Dentist Appointment", "Cleaning + checkup. Will need to leave school early during 6th period.", 4, 14, 30, 1, False),
    ("Family Dinner: Grandma's Birthday", "Dinner at Grandma's house — 80th birthday. Dress nicely.", 7, 18, 0, 3, False),
    ("Club Basketball Game", "Saturday afternoon game vs. Westfield at the rec center. Warmups at 1:30 PM.", 12, 14, 0, 2, False),
    ("Driver's Ed: Behind-the-Wheel", "30-minute behind-the-wheel session with the driving school instructor. Pickup from school.", 3, 15, 30, 1, False),
    ("SAT Prep Session", "Group SAT prep at the public library. Math focus this week.", 11, 18, 0, 2, False),
    ("Movie Night with Friends", "Meeting the group at the AMC for the 7:30 showing. Pickup at 10 PM.", 9, 19, 30, 3, False),
]


# Recurring events: (title, description, weekdays, start_hour, start_min, duration_hours)
# weekdays uses Python's Monday=0..Sunday=6
# Will be created for the next 14 days
RECURRING_EVENTS = [
    ("Volleyball Practice", "After-school volleyball practice in the main gym. Bring knee pads.", [0, 2, 3], 15, 30, 2),  # Mon, Wed, Thu
    ("Club Basketball Practice", "Evening basketball practice at the rec center.", [1], 18, 0, 1.5),  # Tuesday evenings
    ("Chemistry Tutoring", "1-on-1 tutoring with Dr. Patel after school. Bring your problem set questions.", [1], 17, 0, 1),  # Tuesday evenings
    ("Math Tutoring Group", "Group tutoring with the calculus study group at the library.", [3], 17, 0, 1),  # Thursday evenings
    ("Debate Club", "Weekly debate club meeting. Topic this week: federal vs. state regulation.", [4], 15, 30, 1),  # Friday after school
]


class Command(BaseCommand):
    help = "Seed realistic high-school course data + after-school life for an existing user."

    def add_arguments(self, parser):
        parser.add_argument("username", type=str, help="Username to seed data against (must already exist)")
        parser.add_argument("--clear", action="store_true", help="Wipe existing seed data for this user before re-seeding")

    @transaction.atomic
    def handle(self, *args, **options):
        username = options["username"]
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            raise CommandError(f"User '{username}' does not exist. Create the account first via the iOS app or createsuperuser.")

        workspace = Workspace.objects.filter(owner=user, is_personal=True).first()
        if not workspace:
            raise CommandError(f"User '{username}' has no personal workspace.")

        if options["clear"]:
            self._clear(user, workspace)

        self._seed_google_credential_stub(user)
        course_map = self._seed_courses(user)
        cw_count = self._seed_coursework(course_map, workspace, user)
        manual_count = self._seed_manual_events(workspace, user)

        self.stdout.write(self.style.SUCCESS(
            f"\nSeed complete:"
            f"\n  Courses: {len(COURSES)}"
            f"\n  Coursework items: {cw_count} (each also created a calendar event)"
            f"\n  Manual after-school events: {manual_count}"
            f"\n  Total calendar events: {cw_count + manual_count}"
        ))
        self.stdout.write(f"\nUser: {username}  |  Workspace: {workspace.name}")

    def _clear(self, user, workspace):
        self.stdout.write("Clearing existing seed data...")
        seed_courses = Course.objects.filter(user=user, google_course_id__startswith=SEED_PREFIX)

        # Delete classroom-derived calendar events
        CalendarEvent.objects.filter(
            workspace=workspace,
            classroom_coursework__course__in=seed_courses,
        ).delete()

        # Delete manually-seeded after-school events (marked in description)
        manual_deleted, _ = CalendarEvent.objects.filter(
            workspace=workspace,
            event_type=CalendarEvent.EventType.MANUAL,
            description__contains=DEMO_EVENT_MARKER,
        ).delete()

        cw_deleted, _ = Coursework.objects.filter(course__in=seed_courses).delete()
        c_deleted, _ = seed_courses.delete()
        self.stdout.write(f"  Deleted {c_deleted} courses, {cw_deleted} coursework, {manual_deleted} manual events.")

    def _seed_google_credential_stub(self, user):
        """Create a stub GoogleCredential so the iOS app shows the courses tab
        as 'connected' without requiring real OAuth. The Classroom sync task
        only runs for users with a credential, but we use synthetic course IDs
        so the sync's update_or_create won't touch our seeded rows even if it
        runs and gets a 401.
        """
        from django.utils import timezone as tz
        GoogleCredential.objects.update_or_create(
            user=user,
            defaults={
                "access_token": "demo-stub-not-real",
                "refresh_token": "demo-stub-not-real",
                "token_uri": "https://oauth2.googleapis.com/token",
                "client_id": "demo-stub",
                "client_secret": "demo-stub",
                "scopes": [
                    "https://www.googleapis.com/auth/classroom.courses.readonly",
                    "https://www.googleapis.com/auth/classroom.coursework.students.readonly",
                ],
                "expiry": tz.now() + datetime.timedelta(days=365),
                "google_email": f"{user.username}@demo.familyhub.local",
            },
        )
        self.stdout.write("Created stub Google credential (demo only — not a real OAuth token)")

    def _seed_courses(self, user):
        self.stdout.write("Seeding courses...")
        course_map = {}
        for synthetic_id, name, section, teacher, room, description in COURSES:
            full_id = f"{SEED_PREFIX}{synthetic_id}"
            course, created = Course.objects.update_or_create(
                user=user,
                google_course_id=full_id,
                defaults={
                    "name": name,
                    "section": section,
                    "teacher_name": teacher,
                    "room": room,
                    "description": description,
                    "course_state": "ACTIVE",
                    "alternate_link": "",
                    "raw_json": {"seeded": True},
                },
            )
            course_map[synthetic_id] = course
            verb = "Created" if created else "Updated"
            self.stdout.write(f"  {verb}: {name}")
        return course_map

    def _seed_coursework(self, course_map, workspace, user):
        today = timezone.localdate()
        cw_count = 0
        self.stdout.write("Seeding coursework + classroom calendar events...")
        for course_sid, item_sid, title, description, work_type, max_points, days_from_now, hour in COURSEWORK:
            course = course_map.get(course_sid)
            if not course:
                continue

            full_cw_id = f"{SEED_PREFIX}{course_sid}-{item_sid}"
            due_date = today + datetime.timedelta(days=days_from_now)
            # Assignments are never due on Saturday — shift to Sunday
            if due_date.weekday() == 5:  # Saturday
                due_date += datetime.timedelta(days=1)
            due_time = datetime.time(hour, 0)

            cw, _ = Coursework.objects.update_or_create(
                course=course,
                google_coursework_id=full_cw_id,
                defaults={
                    "title": title,
                    "description": description,
                    "work_type": work_type,
                    "state": "PUBLISHED",
                    "max_points": max_points,
                    "due_date": due_date,
                    "due_time": due_time,
                    "alternate_link": "",
                    "raw_json": {"seeded": True},
                },
            )
            cw_count += 1

            due_datetime = timezone.make_aware(datetime.datetime.combine(due_date, due_time))
            CalendarEvent.objects.update_or_create(
                classroom_coursework=cw,
                workspace=workspace,
                defaults={
                    "title": f"[{course.name}] {title}",
                    "description": description,
                    "start_datetime": due_datetime,
                    "end_datetime": due_datetime + datetime.timedelta(hours=1),
                    "all_day": False,
                    "event_type": CalendarEvent.EventType.CLASSROOM,
                    "color": "#4285f4",
                    "created_by": user,
                },
            )
        return cw_count

    def _seed_manual_events(self, workspace, user):
        self.stdout.write("Seeding after-school life...")
        today = timezone.localdate()
        count = 0

        # One-off events
        for title, description, days_from_now, hour, minute, duration_hours, all_day in ONE_OFF_EVENTS:
            event_date = today + datetime.timedelta(days=days_from_now)
            start = timezone.make_aware(datetime.datetime.combine(event_date, datetime.time(hour, minute)))
            end = start + datetime.timedelta(hours=duration_hours)
            CalendarEvent.objects.create(
                workspace=workspace,
                title=title,
                description=f"{description} [{DEMO_EVENT_MARKER}]",
                start_datetime=start,
                end_datetime=end,
                all_day=all_day,
                event_type=CalendarEvent.EventType.MANUAL,
                color="#22c55e",
                created_by=user,
            )
            count += 1

        # Recurring events: expand into individual occurrences over the next 14 days
        for title, description, weekdays, hour, minute, duration_hours in RECURRING_EVENTS:
            for day_offset in range(14):
                event_date = today + datetime.timedelta(days=day_offset)
                if event_date.weekday() in weekdays:
                    start = timezone.make_aware(datetime.datetime.combine(event_date, datetime.time(hour, minute)))
                    end = start + datetime.timedelta(hours=duration_hours)
                    CalendarEvent.objects.create(
                        workspace=workspace,
                        title=title,
                        description=f"{description} [{DEMO_EVENT_MARKER}]",
                        start_datetime=start,
                        end_datetime=end,
                        all_day=False,
                        event_type=CalendarEvent.EventType.MANUAL,
                        color="#f59e0b",
                        created_by=user,
                    )
                    count += 1

        self.stdout.write(f"  Created {count} after-school events.")
        return count
