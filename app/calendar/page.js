"use client";
import AppShell from '../../components/AppShell';
import TimetableCalendar from '../../components/TimetableCalendar';
import {useSchoolContext} from '../../lib/useSchoolContext';
export default function Calendar(){const {school,role}=useSchoolContext();return <AppShell active="Calendar" schoolName={school?.name} role={role}><TimetableCalendar/></AppShell>}
