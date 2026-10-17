# WorkManager's Room database is constructed by name during AndroidX startup.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
