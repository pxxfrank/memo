/* 快速记录窗 preload：暴露保存/关闭能力 */
const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('memoAPI', {
  save: (content) => ipcRenderer.invoke('capture-save', content),
  close: () => ipcRenderer.invoke('capture-close'),
})
