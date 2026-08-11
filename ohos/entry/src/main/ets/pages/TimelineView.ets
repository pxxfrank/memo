/**
 * 笔记时间线：输入 + 富文本卡片 + 置顶/编辑/删除/复制
 */
import { Memo, MemoStore } from '../model/MemoStore';
import { RichText } from '../components/RichText';
import { FormatToolbar, FormatKind, applyFormatToText } from '../components/FormatToolbar';
import { pasteboard } from '@kit.BasicServicesKit';

@CustomDialog
struct EditDialog {
  controller: CustomDialogController;
  @State text: string = '';
  content: string = '';
  onSave: (text: string) => void = () => {};

  aboutToAppear(): void {
    this.text = this.content;
  }

  build() {
    Column() {
      Text('编辑笔记')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#37352F')
        .margin({ bottom: 12 })
      TextArea({ text: this.text, placeholder: '修改内容……' })
        .height(140)
        .fontSize(14)
        .onChange((v: string) => {
          this.text = v;
        })
      Row({ space: 4 }) {
        FormatToolbar({ onFormat: (kind: FormatKind) => {
          const r = applyFormatToText(this.text, 0, this.text.length, kind);
          this.text = r.text;
        } })
      }
      .margin({ top: 8 })
      Row({ space: 12 }) {
        Button('取消')
          .backgroundColor('#00000000')
          .fontColor('#8E8B84')
          .onClick(() => {
            this.controller.close();
          })
        Button('保存')
          .backgroundColor('#43B581')
          .onClick(() => {
            this.controller.close();
            this.onSave(this.text.trim());
          })
      }
      .margin({ top: 16 })
      .justifyContent(FlexAlign.End)
    }
    .padding(20)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}

@Component
export struct TimelineView {
  @State memos: Memo[] = [];
  @State input: string = '';
  @State selStart: number = 0;
  @State selEnd: number = 0;
  private textAreaController: TextAreaController = new TextAreaController();
  private editDlg: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.memos = await MemoStore.list();
  }

  private async submit(): Promise<void> {
    const text = this.input.trim();
    if (text.length === 0) {
      return;
    }
    await MemoStore.insert(text);
    this.input = '';
    this.textAreaController.caretPosition(0);
    await this.load();
  }

  private onFormat(kind: FormatKind): void {
    const s = Math.min(this.selStart, this.selEnd);
    const e = Math.max(this.selStart, this.selEnd);
    const r = applyFormatToText(this.input, s, e, kind);
    this.input = r.text;
    this.textAreaController.caretPosition(r.end);
    this.selStart = r.start;
    this.selEnd = r.end;
  }

  private async togglePin(m: Memo): Promise<void> {
    await MemoStore.togglePin(m.id, m.pinned === 1 ? 0 : 1);
    await this.load();
  }

  private openEdit(m: Memo): void {
    this.editDlg = new CustomDialogController({
      builder: EditDialog({
        content: m.content,
        onSave: (t: string) => {
          this.saveEdit(m, t);
        },
      }),
      autoCancel: true,
    });
    this.editDlg.open();
  }

  private async saveEdit(m: Memo, text: string): Promise<void> {
    if (text.length > 0 && text !== m.content) {
      await MemoStore.update(m.id, text);
      await this.load();
    }
  }

  private async remove(m: Memo): Promise<void> {
    AlertDialog.show({
      title: '删除这条笔记？',
      message: '删除后可通过云同步的墓碑在其他设备同步删除，无法恢复。',
      primaryButton: {
        value: '取消',
        action: () => {},
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E84026',
        action: () => {
          MemoStore.remove(m.id).then(() => {
            this.load();
          });
        },
      },
    });
  }

  private copy(m: Memo): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, m.content);
    pasteboard.getSystemPasteboard().setData(data);
  }

  private fmtTime(ts: number): string {
    const d = new Date(ts);
    const hh = d.getHours().toString().padStart(2, '0');
    const mm = d.getMinutes().toString().padStart(2, '0');
    return hh + ':' + mm;
  }

  build() {
    Column() {
      // 输入区
      Column() {
        TextArea({
          text: this.input,
          placeholder: '现在的想法是……',
          controller: this.textAreaController,
        })
          .height(72)
          .fontSize(15)
          .backgroundColor('#FFFFFF')
          .onChange((v: string) => {
            this.input = v;
          })
          .onTextSelectionChange((start: number, end: number) => {
            this.selStart = start;
            this.selEnd = end;
          })
        Row() {
          FormatToolbar({ onFormat: (kind: FormatKind) => {
            this.onFormat(kind);
          } })
          Blank()
          Button('发送')
            .height(34)
            .fontSize(13)
            .backgroundColor(this.input.trim().length > 0 ? '#43B581' : '#B5B2AA')
            .enabled(this.input.trim().length > 0)
            .onClick(() => {
              this.submit();
            })
        }
        .width('100%')
        .padding({ top: 6 })
      }
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .border({ width: 1, color: '#E9E7E1' })
      .margin({ left: 14, right: 14, top: 8, bottom: 8 })

      // 时间线
      List({ space: 10 }) {
        ForEach(this.memos, (m: Memo) => {
          ListItem() {
            Column() {
              Row() {
                if (m.pinned === 1) {
                  Text('置顶')
                    .fontSize(10)
                    .fontColor('#F5A623')
                    .backgroundColor('#FFF6E5')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(8)
                    .margin({ right: 6 })
                }
                Text(this.fmtTime(m.createdAt))
                  .fontSize(11)
                  .fontColor('#B5B2AA')
                Blank()
              }
              .width('100%')
              .margin({ bottom: 6 })

              RichText({ content: m.content })

              Row({ space: 14 }) {
                Text('📌')
                  .fontSize(15)
                  .onClick(() => {
                    this.togglePin(m);
                  })
                Text('✏️')
                  .fontSize(15)
                  .onClick(() => {
                    this.openEdit(m);
                  })
                Text('📋')
                  .fontSize(15)
                  .onClick(() => {
                    this.copy(m);
                  })
                Text('🗑️')
                  .fontSize(15)
                  .onClick(() => {
                    this.remove(m);
                  })
              }
              .width('100%')
              .margin({ top: 10 })
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E9E7E1' })
          }
        }, (m: Memo) => m.uuid)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 14, right: 14, bottom: 14 })

      if (this.memos.length === 0) {
        Text('还没有笔记，写下第一条吧')
          .fontSize(13.5)
          .fontColor('#B5B2AA')
          .margin({ top: 40 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F6F3')
  }
}
