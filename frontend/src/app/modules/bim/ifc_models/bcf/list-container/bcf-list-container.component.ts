import {ChangeDetectionStrategy, Component, OnInit} from "@angular/core";
import {WorkPackageViewHandlerToken} from "core-app/modules/work_packages/routing/wp-view-base/event-handling/event-handler-registry";
import {BcfCardViewHandlerRegistry} from "core-app/modules/bim/ifc_models/ifc-base-view/event-handler/bcf-card-view-handler-registry";
import {WorkPackageListViewComponent} from "core-app/modules/work_packages/routing/wp-list-view/wp-list-view.component";
import {QueryResource} from "core-app/modules/hal/resources/query-resource";
import {HalResourceNotificationService} from "core-app/modules/hal/services/hal-resource-notification.service";
import {WorkPackageNotificationService} from "core-app/modules/work_packages/notifications/work-package-notification.service";
import {DragAndDropService} from "core-app/modules/common/drag-and-drop/drag-and-drop.service";
import {CausedUpdatesService} from "core-app/modules/boards/board/caused-updates/caused-updates.service";
import {bimSplitViewIdentifier, BimViewService} from "core-app/modules/bim/ifc_models/pages/viewer/bim-view.service";
import {InjectField} from "core-app/helpers/angular/inject-field.decorator";
import {wpDisplayCardRepresentation, wpDisplayListRepresentation} from "core-app/modules/work_packages/routing/wp-view-base/view-services/wp-view-display-representation.service";
import {IfcModelsDataService} from "core-app/modules/bim/ifc_models/pages/viewer/ifc-models-data.service";
import {WorkPackageViewColumnsService} from 'core-app/modules/work_packages/routing/wp-view-base/view-services/wp-view-columns.service';
import {UIRouterGlobals, UIRouter, TransitionService} from '@uirouter/core';
import {pluck, distinctUntilChanged, filter} from "rxjs/operators";

@Component({
  templateUrl: '/app/modules/work_packages/routing/wp-list-view/wp-list-view.component.html',
  styleUrls: ['/app/modules/work_packages/routing/wp-list-view/wp-list-view.component.sass'],
  providers: [
    { provide: WorkPackageViewHandlerToken, useValue: BcfCardViewHandlerRegistry },
    { provide: HalResourceNotificationService, useClass: WorkPackageNotificationService },
    DragAndDropService,
    CausedUpdatesService
  ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class BcfListContainerComponent extends WorkPackageListViewComponent implements OnInit {  
  @InjectField() bimView:BimViewService;
  @InjectField() ifcModelsService:IfcModelsDataService;
  @InjectField() wpTableColumns:WorkPackageViewColumnsService;
  @InjectField() uIRouterGlobals:UIRouterGlobals

  public wpTableConfiguration = {
    dragAndDropEnabled: false
  };

  ngOnInit() {
    super.ngOnInit();

    // Ensure we add a bcf thumbnail column
    // until we can load the initial query
    this.wpTableColumns
          .onReady()
          .then(() => {
            this.wpTableColumns.addColumn('bcfThumbnail', 2);
          });

    this.uIRouterGlobals
          .params$!
          .pipe(
            this.untilDestroyed(),
            pluck('cards'),
            distinctUntilChanged(),
          )
          .subscribe((cards:boolean) => {
            if (cards || cards == null) {
              this.wpDisplayRepresentation.setDisplayRepresentation(wpDisplayCardRepresentation);
            } else {
              this.wpDisplayRepresentation.setDisplayRepresentation(wpDisplayListRepresentation);
            }

            this.cdRef.detectChanges();
          });
  }
  
  protected updateViewRepresentation(query:QueryResource) {
    if (this.wpDisplayRepresentation.current === null) {
      this.wpDisplayRepresentation.setDisplayRepresentation(wpDisplayCardRepresentation);
    }

    super.updateViewRepresentation(query);
  }

  protected showResizerInCardView():boolean {
    if (this.noResults && this.ifcModelsService.models.length === 0) {
      return false;
    } else {
      return this.bimView.currentViewerState() === bimSplitViewIdentifier;
    }
  }
}
