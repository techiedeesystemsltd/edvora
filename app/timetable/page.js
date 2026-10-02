"use client";
import AppShell from '../../components/AppShell';
import TimetableCalendar from '../../components/TimetableCalendar';
import {useSchoolContext} from '../../lib/useSchoolContext';
export default function Timetable(){const {school,role}=useSchoolContext();return <AppShell active="Timetable" schoolName={school?.name} role={role}><TimetableCalendar/></AppShell>}
