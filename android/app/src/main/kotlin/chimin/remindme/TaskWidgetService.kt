package chimin.remindme

import android.content.Context
import android.content.Intent
import android.widget.RemoteViewsService

class TaskWidgetService : RemoteViewsService() {

  override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
    return TaskWidgetFactory(this, intent)
  }
}