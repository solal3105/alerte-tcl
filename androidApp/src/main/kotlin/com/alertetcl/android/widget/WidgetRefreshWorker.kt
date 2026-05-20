package com.alertetcl.android.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Rafraîchit tous les widgets actifs toutes les 15 minutes (minimum WorkManager).
 * Schedulé via [WidgetRefreshScheduler.schedule] depuis les receivers Glance.
 * Requiert le réseau pour éviter les tentatives inutiles en Doze.
 */
internal class WidgetRefreshWorker(ctx: Context, params: WorkerParameters) :
    CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result {
        val manager = GlanceAppWidgetManager(applicationContext)
        manager.getGlanceIds(NextDeparturesGlanceWidget::class.java)
            .forEach { id -> NextDeparturesGlanceWidget().update(applicationContext, id) }
        manager.getGlanceIds(TCLBoardGlanceWidget::class.java)
            .forEach { id -> TCLBoardGlanceWidget().update(applicationContext, id) }
        return Result.success()
    }
}

internal object WidgetRefreshScheduler {
    private const val WORK_NAME = "widget_passage_refresh"

    fun schedule(context: Context) {
        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .build()
        )
    }
}
