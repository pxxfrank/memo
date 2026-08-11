/**
 * MEMO 数据层：本地 SQLite（relationalStore）
 * 表结构与 Windows/Android/macOS 端完全一致，云同步按 UUID 互通。
 * 字段：id / uuid / content / created_at / updated_at / pinned
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

export interface Memo {
  id: number;
  uuid: string;
  content: string;
  createdAt: number;
  updatedAt: number;
  pinned: number;
}

export class TagCount {
  name: string = '';
  count: number = 0;
}

export interface Stats {
  total: number;
  weekNew: number;
  todayNew: number;
  streak: number;
  topTags: TagCount[];
}

const CREATE_SQL: string = `CREATE TABLE IF NOT EXISTS memos(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0)`;

const SELECT_COLS: string = 'id, uuid, content, created_at, updated_at, pinned';

export class MemoStore {
  private static store: relationalStore.RdbStore | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (MemoStore.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'memo.db',
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    const store = await relationalStore.getRdbStore(context, config);
    await store.executeSql(CREATE_SQL);
    MemoStore.store = store;
  }

  static getStore(): relationalStore.RdbStore | null {
    return MemoStore.store;
  }

  private static rowToMemo(rs: relationalStore.ResultSet): Memo {
    const memo: Memo = {
      id: rs.getLong(rs.getColumnIndex('id')),
      uuid: rs.getString(rs.getColumnIndex('uuid')),
      content: rs.getString(rs.getColumnIndex('content')),
      createdAt: rs.getLong(rs.getColumnIndex('created_at')),
      updatedAt: rs.getLong(rs.getColumnIndex('updated_at')),
      pinned: rs.getLong(rs.getColumnIndex('pinned')),
    };
    return memo;
  }

  static async list(): Promise<Memo[]> {
    const store = MemoStore.store;
    if (store === null) {
      return [];
    }
    const rs = await store.querySql(
      `SELECT ${SELECT_COLS} FROM memos ORDER BY pinned DESC, created_at DESC`);
    const list: Memo[] = [];
    while (rs.goToNextRow()) {
      list.push(MemoStore.rowToMemo(rs));
    }
    rs.close();
    return list;
  }

  static async insert(content: string): Promise<Memo> {
    const store = MemoStore.store;
    if (store === null) {
      throw new Error('store not initialized');
    }
    const now = Date.now();
    const memo: Memo = {
      id: 0,
      uuid: util.generateRandomUUID(),
      content: content,
      createdAt: now,
      updatedAt: now,
      pinned: 0,
    };
    await store.executeSql(
      'INSERT INTO memos(uuid, content, created_at, updated_at, pinned) VALUES(?,?,?,?,?)',
      [memo.uuid, memo.content, memo.createdAt, memo.updatedAt, memo.pinned]);
    const rs = await store.querySql(
      `SELECT ${SELECT_COLS} FROM memos WHERE uuid = ?`, [memo.uuid]);
    if (rs.goToNextRow()) {
      memo.id = rs.getLong(rs.getColumnIndex('id'));
    }
    rs.close();
    return memo;
  }

  static async update(id: number, content: string): Promise<void> {
    const store = MemoStore.store;
    if (store === null) {
      return;
    }
    await store.executeSql(
      'UPDATE memos SET content = ?, updated_at = ? WHERE id = ?',
      [content, Date.now(), id]);
  }

  static async togglePin(id: number, pinned: number): Promise<void> {
    const store = MemoStore.store;
    if (store === null) {
      return;
    }
    await store.executeSql(
      'UPDATE memos SET pinned = ?, updated_at = ? WHERE id = ?',
      [pinned, Date.now(), id]);
  }

  static async remove(id: number): Promise<void> {
    const store = MemoStore.store;
    if (store === null) {
      return;
    }
    await store.executeSql('DELETE FROM memos WHERE id = ?', [id]);
  }

  /** 按 UUID 更新（云同步合并用） */
  static async upsertByUuid(uuid: string, content: string, createdAt: number,
    updatedAt: number, pinned: number): Promise<void> {
    const store = MemoStore.store;
    if (store === null) {
      return;
    }
    const rs = await store.querySql('SELECT id FROM memos WHERE uuid = ?', [uuid]);
    const exists = rs.goToNextRow();
    const id = exists ? rs.getLong(rs.getColumnIndex('id')) : 0;
    rs.close();
    if (exists) {
      await store.executeSql(
        'UPDATE memos SET content = ?, created_at = ?, updated_at = ?, pinned = ? WHERE id = ?',
        [content, createdAt, updatedAt, pinned, id]);
    } else {
      await store.executeSql(
        'INSERT INTO memos(uuid, content, created_at, updated_at, pinned) VALUES(?,?,?,?,?)',
        [uuid, content, createdAt, updatedAt, pinned]);
    }
  }

  /** 删除（云同步墓碑） */
  static async removeByUuid(uuid: string): Promise<void> {
    const store = MemoStore.store;
    if (store === null) {
      return;
    }
    await store.executeSql('DELETE FROM memos WHERE uuid = ?', [uuid]);
  }

  static async stats(): Promise<Stats> {
    const store = MemoStore.store;
    if (store === null) {
      return { total: 0, weekNew: 0, todayNew: 0, streak: 0, topTags: [] };
    }
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    // 本周一零点
    const day = now.getDay() === 0 ? 7 : now.getDay();
    const startOfWeek = startOfDay - (day - 1) * 86400000;

    const rsTotal = await store.querySql('SELECT COUNT(*) AS c FROM memos');
    const total = rsTotal.goToNextRow() ? rsTotal.getLong(rsTotal.getColumnIndex('c')) : 0;
    rsTotal.close();

    const rsWeek = await store.querySql(
      'SELECT COUNT(*) AS c FROM memos WHERE created_at >= ?', [startOfWeek]);
    const weekNew = rsWeek.goToNextRow() ? rsWeek.getLong(rsWeek.getColumnIndex('c')) : 0;
    rsWeek.close();

    const rsToday = await store.querySql(
      'SELECT COUNT(*) AS c FROM memos WHERE created_at >= ?', [startOfDay]);
    const todayNew = rsToday.goToNextRow() ? rsToday.getLong(rsToday.getColumnIndex('c')) : 0;
    rsToday.close();

    // 连续记录天数（按天去重，从今天/昨天起往前数）
    const rsDays = await store.querySql(
      'SELECT DISTINCT created_at FROM memos ORDER BY created_at DESC');
    const seen: Set<number> = new Set();
    const days: number[] = [];
    while (rsDays.goToNextRow()) {
      const ts = rsDays.getLong(rsDays.getColumnIndex('created_at'));
      const d = new Date(ts);
      const dayTs = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
      if (!seen.has(dayTs)) {
        seen.add(dayTs);
        days.push(dayTs);
      }
    }
    rsDays.close();
    let streak = 0;
    let expect = startOfDay;
    // 今天没记则从昨天开始
    if (days.length > 0 && days[0] < startOfDay) {
      expect = startOfDay - 86400000;
    }
    for (const d of days) {
      if (d === expect) {
        streak++;
        expect -= 86400000;
      } else {
        break;
      }
    }

    // 常用标签 Top5
    const tagCount: Map<string, number> = new Map();
    const rsAll = await store.querySql('SELECT content FROM memos');
    const tagRe = /#[^\s#，。！？!?,;；:："“”‘’（）()【】\[\]<>《》]+/g;
    while (rsAll.goToNextRow()) {
      const content = rsAll.getString(rsAll.getColumnIndex('content'));
      const matches = content.match(tagRe);
      if (matches) {
        for (const m of matches) {
          const tag = m.replace(/[，。！？；、,.!?;:]+$/, '');
          tagCount.set(tag, (tagCount.get(tag) ?? 0) + 1);
        }
      }
    }
    rsAll.close();
    const sorted: Array<[string, number]> = Array.from(tagCount.entries());
    sorted.sort((a, b) => b[1] - a[1]);
    const topTags: TagCount[] = [];
    for (let i = 0; i < Math.min(5, sorted.length); i++) {
      const t = new TagCount();
      t.name = sorted[i][0];
      t.count = sorted[i][1];
      topTags.push(t);
    }

    return { total, weekNew, todayNew, streak, topTags };
  }
}
