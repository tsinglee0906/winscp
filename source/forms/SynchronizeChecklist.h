//----------------------------------------------------------------------------
#ifndef SynchronizeChecklistH
#define SynchronizeChecklistH
//----------------------------------------------------------------------------
#include "IEListView.hpp"
#include "NortonLikeListView.hpp"
#include <System.Classes.hpp>
#include <Vcl.ComCtrls.hpp>
#include <Vcl.Controls.hpp>
#include <Vcl.ExtCtrls.hpp>
#include <Vcl.ImgList.hpp>
#include <Vcl.Menus.hpp>
#include <Vcl.StdCtrls.hpp>
#include "PngImageList.hpp"
//----------------------------------------------------------------------------
#include <Terminal.h>
#include <System.Actions.hpp>
#include <Vcl.ActnList.hpp>
//----------------------------------------------------------------------------
class TSynchronizeChecklistDialog : public TForm
{
__published:
  TPanel * Panel;
  TIEListView *ListView;
  TStatusBar *StatusBar;
  TPngImageList *ActionImages;
  TButton *OkButton;
  TButton *CancelButton;
  TButton *CheckAllButton;
  TButton *UncheckAllButton;
  TButton *CheckButton;
  TButton *UncheckButton;
  TPopupMenu *ListViewPopupMenu;
  TMenuItem *CheckItem;
  TMenuItem *UncheckItem;
  TMenuItem *N1;
  TMenuItem *SelectAllItem;
  TTimer *UpdateTimer;
  TButton *HelpButton;
  TButton *CustomCommandsButton2;
  TActionList *ActionList;
  TAction *CheckAction;
  TAction *UncheckAction;
  TAction *CheckAllAction;
  TAction *UncheckAllAction;
  TAction *SelectAllAction;
  TAction *CustomCommandsAction;
  TMenuItem *N2;
  TButton *ReverseButton;
  TAction *ReverseAction;
  TMenuItem *ReverseItem;
  TPngImageList *ActionImages120;
  TPngImageList *ActionImages144;
  TPngImageList *ActionImages192;
  TAction *CalculateSizeAction;
  TMenuItem *Calculate1;
  TButton *CalculateSizeButton;
  TAction *CalculateSizeAllAction;
  TAction *MoveAction;
  TButton *MoveButton;
  TMenuItem *MoveItem;
  TAction *CheckDirectoryAction;
  TAction *UncheckDirectoryAction;
  TMenuItem *N3;
  TMenuItem *CheckAllFilesinThisDirectory1;
  TMenuItem *UncheckAllActionsinThisDirectory1;
  void __fastcall HelpButtonClick(TObject * Sender);
  void __fastcall FormShow(TObject * Sender);
  void __fastcall StatusBarDrawPanel(TStatusBar *StatusBar,
          TStatusPanel *Panel, const TRect &Rect);
  void __fastcall StatusBarMouseMove(TObject *Sender, TShiftState Shift,
          int X, int Y);
  void __fastcall ListViewChange(TObject *Sender, TListItem *Item,
          TItemChange Change);
  void __fastcall ListViewChanging(TObject *Sender, TListItem *Item,
          TItemChange Change, bool &AllowChange);
  void __fastcall CheckAllActionExecute(TObject *Sender);
  void __fastcall CheckActionExecute(TObject *Sender);
  void __fastcall ListViewSelectItem(TObject *Sender, TListItem *Item,
          bool Selected);
  void __fastcall UpdateTimerTimer(TObject *Sender);
  void __fastcall SelectAllActionExecute(TObject *Sender);
  void __fastcall StatusBarMouseDown(TObject *Sender, TMouseButton Button,
          TShiftState Shift, int X, int Y);
  void __fastcall ListViewCompare(TObject *Sender, TListItem *Item1,
          TListItem *Item2, int Data, int &Compare);
  void __fastcall ListViewSecondaryColumnHeader(TCustomIEListView *Sender,
          int Index, int &SecondaryColumn);
  void __fastcall ListViewContextPopup(TObject *Sender, TPoint &MousePos,
          bool &Handled);
  void __fastcall CustomCommandsActionExecute(TObject *Sender);
  void __fastcall ListViewAdvancedCustomDrawSubItem(TCustomListView *Sender, TListItem *Item,
          int SubItem, TCustomDrawState State, TCustomDrawStage Stage, bool &DefaultDraw);
  void __fastcall StatusBarResize(TObject *Sender);
  void __fastcall UncheckActionExecute(TObject *Sender);
  void __fastcall UncheckAllActionExecute(TObject *Sender);
  void __fastcall ReverseActionExecute(TObject *Sender);
  void __fastcall ListViewClick(TObject *Sender);
  void __fastcall OkButtonClick(TObject *Sender);
  void __fastcall CalculateSizeActionExecute(TObject *Sender);
  void __fastcall CalculateSizeAllActionExecute(TObject *Sender);
  void __fastcall MoveActionExecute(TObject *Sender);
  void __fastcall CheckDirectoryActionExecute(TObject *Sender);
  void __fastcall UncheckDirectoryActionExecute(TObject *Sender);

public:
  __fastcall TSynchronizeChecklistDialog(
    TComponent * AOwner, TSynchronizeMode Mode, int Params,
    const UnicodeString & LocalDirectory, const UnicodeString & RemoteDirectory,
    TCustomCommandMenuEvent OnCustomCommandMenu, TFullSynchronizeEvent OnSynchronize,
    TSynchronizeChecklistCalculateSize OnSynchronizeChecklistCalculateSize, TSynchronizeMoveEvent OnSynchronizeMove,
    void * Token);
  virtual __fastcall ~TSynchronizeChecklistDialog();

  bool __fastcall Execute(TSynchronizeChecklist * Checklist);

protected:
  bool FFormRestored;
  TSynchronizeChecklist * FChecklist;
  TSynchronizeMode FMode;
  int FParams;
  UnicodeString FLocalDirectory;
  UnicodeString FRemoteDirectory;
  TWndMethod FOrigListViewWindowProc;
  int FTotals[1 + TSynchronizeChecklist::ActionCount];
  int FChecked[1 + TSynchronizeChecklist::ActionCount];
  __int64 FCheckedSize[1 + TSynchronizeChecklist::ActionCount];
  TListItem * FChangingItem;
  bool FChangingItemChecked;
  bool FChangingItemIgnore;
  bool FChangingItemMass;
  UnicodeString FGeneralHint;
  TCustomCommandMenuEvent FOnCustomCommandMenu;
  TSynchronizeChecklistCalculateSize FOnSynchronizeChecklistCalculateSize;
  TSynchronizeMoveEvent FOnSynchronizeMove;
  typedef std::map<const TSynchronizeChecklist::TItem *, TSynchronizeChecklist::TAction> TActions;
  TActions FActions;
  TFullSynchronizeEvent FOnSynchronize;
  void * FToken;
  bool FSynchronizing;
  std::unique_ptr<Exception> FException;
  std::map<const TSynchronizeChecklist::TItem *, TListItem *> FChecklistToListViewMap;

  void __fastcall UpdateControls();
  void __fastcall UpdateCaption();
  virtual void __fastcall CreateParams(TCreateParams & Params);
  void __fastcall LoadItem(TListItem * Item);
  void __fastcall LoadList();
  void __fastcall ListViewWindowProc(TMessage & Message);
  int __fastcall PanelAt(int X);
  void __fastcall CheckAll(bool Check);
  void __fastcall Check(bool Check);
  TListItem * __fastcall SelectAll(bool Select, int Action = 0,
    bool OnlyTheAction = true);
  void __fastcall UpdateStatusBarSize();
  int __fastcall PanelCount();
  inline const TSynchronizeChecklist::TItem * GetChecklistItem(TListItem * Item);
  TSynchronizeChecklist::TAction & GetChecklistItemAction(
    const TSynchronizeChecklist::TItem * ChecklistItem);
  void __fastcall AddSubItem(TListItem * Item, int & Index, const UnicodeString & S);
  TRect __fastcall GetColumnHeaderRect(int Index);
  virtual void __fastcall Dispatch(void * Message);
  void __fastcall UpdateImages();
  void __fastcall CMDpiChanged(TMessage & Message);
  bool __fastcall GetWindowParams(UnicodeString & WindowParams);
  void __fastcall ProcessedItem(void * Token, const TSynchronizeChecklist::TItem * ChecklistItem);
  void __fastcall UpdatedSynchronizationChecklistItems(const TSynchronizeChecklist::TItemList & Items);
  void __fastcall CountItemSize(const TSynchronizeChecklist::TItem * ChecklistItem, int Factor);
  void __fastcall CountItem(const TSynchronizeChecklist::TItem * ChecklistItem, int Factor);
  void __fastcall CountItemTotal(const TSynchronizeChecklist::TItem * ChecklistItem, int Factor);
  typedef std::pair<const TSynchronizeChecklist::TItem *, const TSynchronizeChecklist::TItem *> TSynchronizeMoveItems;
  TSynchronizeMoveItems __fastcall GetMoveItems();
  void __fastcall DeleteItem(TListItem * Item);
  void __fastcall CheckDirectory(bool Check);
  static int __fastcall CompareNumber(__int64 Value1, __int64 Value2);
};
//----------------------------------------------------------------------------
#endif
