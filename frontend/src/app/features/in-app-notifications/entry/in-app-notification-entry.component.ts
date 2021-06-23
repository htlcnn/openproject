import { ChangeDetectionStrategy, Component, Input, OnInit } from '@angular/core';
import { InAppNotification } from "core-app/features/in-app-notifications/store/in-app-notification.model";
import { WorkPackageResource } from "core-app/features/hal/resources/work-package-resource";
import { NEVER, Observable } from "rxjs";
import { APIV3Service } from "core-app/core/apiv3/api-v3.service";
import { HalResource } from "core-app/features/hal/resources/hal-resource";
import { I18nService } from "core-app/core/i18n/i18n.service";
import { InAppNotificationsService } from "core-app/features/in-app-notifications/store/in-app-notifications.service";

@Component({
  selector: 'op-in-app-notification-entry',
  templateUrl: './in-app-notification-entry.component.html',
  styleUrls: ['./in-app-notification-entry.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class InAppNotificationEntryComponent implements OnInit {
  @Input() notification:InAppNotification;

  workPackage$:Observable<WorkPackageResource>|null = null;

  text = {
    loading: this.I18n.t('js.ajax.loading'),
  };

  constructor(
    readonly apiV3Service:APIV3Service,
    readonly I18n:I18nService,
    readonly inAppNotificationsService:InAppNotificationsService
  ) {
  }

  ngOnInit() {
    const href = this.notification._links.resource?.href;
    const id = href && HalResource.matchFromLink(href, 'work_packages');

    // Not a work package reference
    if (id) {
      this.workPackage$ = this
        .apiV3Service
        .work_packages
        .id(id)
        .requireAndStream();
    }
  }

  toggleDetails() {
    if(!this.notification.read) {
      this.inAppNotificationsService.markReadKeepAndExpanded(this.notification);
    }
    if(this.notification.expanded) {
      this.inAppNotificationsService.collapse(this.notification);
    } else {
      this.inAppNotificationsService.expand(this.notification);
    }
  }
}
