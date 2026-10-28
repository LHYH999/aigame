#!/usr/bin/env python3
"""Build the current GDD and daily production log as a formatted workbook."""

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DEPS = ROOT / ".tmp" / "python-deps"
if DEPS.exists():
    sys.path.insert(0, str(DEPS))

# Re-import after the local dependency path is available.
from openpyxl import Workbook, load_workbook  # noqa: E402
from openpyxl.drawing.image import Image as XLImage  # noqa: E402
from openpyxl.formatting.rule import DataBarRule  # noqa: E402
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side  # noqa: E402
from openpyxl.utils import get_column_letter  # noqa: E402
from openpyxl.worksheet.table import Table, TableStyleInfo  # noqa: E402


OUTPUT = ROOT / "docs" / "game-design" / "逆岁四契_游戏策划案_v1.7.xlsx"
REFERENCE_IMAGE = ROOT / "docs" / "game-design" / "assets" / "four-symbols-reference.jpg"

TITLE_FONT = "Microsoft YaHei"
BODY_FONT = "Microsoft YaHei"
COLORS = {
    "ink": "1D2A2A",
    "teal": "1F5F5B",
    "deep_teal": "174844",
    "jade": "4F8F83",
    "paper": "F4F0E6",
    "cream": "E8DEC8",
    "gold": "B99042",
    "pale_gold": "F2E4BC",
    "red": "9B3F35",
    "pale_red": "F4D8D2",
    "blue": "3E6680",
    "pale_blue": "DCEAF2",
    "green": "3D765A",
    "pale_green": "DDEDE3",
    "gray": "68716F",
    "pale_gray": "E6E9E7",
    "white": "FFFFFF",
    "black": "111717",
}

THIN_BORDER = Border(
    left=Side(style="thin", color="CFD6D2"),
    right=Side(style="thin", color="CFD6D2"),
    top=Side(style="thin", color="CFD6D2"),
    bottom=Side(style="thin", color="CFD6D2"),
)


def title_font(size: int, color: str = COLORS["ink"]) -> Font:
    return Font(name=TITLE_FONT, size=size, bold=True, color=color)


def body_font(
    size: int = 10,
    bold: bool = False,
    color: str = COLORS["ink"],
) -> Font:
    return Font(name=BODY_FONT, size=size, bold=bold, color=color)


def solid_fill(color: str) -> PatternFill:
    return PatternFill(fill_type="solid", fgColor=color)


def set_sheet_defaults(ws, *, landscape: bool = True) -> None:
    ws.sheet_view.showGridLines = False
    ws.sheet_view.zoomScale = 90
    ws.page_setup.orientation = "landscape" if landscape else "portrait"
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_margins.left = 0.25
    ws.page_margins.right = 0.25
    ws.page_margins.top = 0.45
    ws.page_margins.bottom = 0.45


def add_heading(ws, title: str, subtitle: str, end_col: int = 8) -> int:
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=end_col)
    title_cell = ws.cell(1, 1, title)
    title_cell.font = title_font(19, COLORS["white"])
    title_cell.fill = solid_fill(COLORS["deep_teal"])
    title_cell.alignment = Alignment(vertical="center")
    ws.row_dimensions[1].height = 34

    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=end_col)
    subtitle_cell = ws.cell(2, 1, subtitle)
    subtitle_cell.font = body_font(10, color=COLORS["gray"])
    subtitle_cell.fill = solid_fill(COLORS["paper"])
    subtitle_cell.alignment = Alignment(vertical="center", wrap_text=True)
    ws.row_dimensions[2].height = 30
    return 4


def write_section(ws, row: int, title: str, end_col: int = 8) -> int:
    ws.merge_cells(
        start_row=row,
        start_column=1,
        end_row=row,
        end_column=end_col,
    )
    cell = ws.cell(row, 1, title)
    cell.font = title_font(11, COLORS["white"])
    cell.fill = solid_fill(COLORS["teal"])
    cell.alignment = Alignment(vertical="center")
    ws.row_dimensions[row].height = 24
    return row + 1


def status_fill(status: str) -> PatternFill | None:
    status = status.strip()
    if any(token in status for token in ("已完成", "已修正", "通过")):
        return solid_fill(COLORS["pale_green"])
    if any(token in status for token in ("已确认", "待制作", "待实现", "规划")):
        return solid_fill(COLORS["pale_gold"])
    if any(token in status for token in ("验证", "持续", "联调")):
        return solid_fill(COLORS["pale_blue"])
    if any(token in status for token in ("风险", "阻塞", "待决")):
        return solid_fill(COLORS["pale_red"])
    return None


def write_table(
    ws,
    start_row: int,
    headers: list[str],
    rows: list[list[object]],
    widths: list[int],
    *,
    table_name: str | None = None,
    freeze: bool = False,
    status_col: int | None = None,
    center_cols: set[int] | None = None,
    number_formats: dict[int, str] | None = None,
) -> int:
    center_cols = center_cols or set()
    number_formats = number_formats or {}

    for index, width in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(index)].width = width

    for col_index, header in enumerate(headers, start=1):
        cell = ws.cell(start_row, col_index, header)
        cell.font = body_font(10, bold=True, color=COLORS["white"])
        cell.fill = solid_fill(COLORS["deep_teal"])
        cell.alignment = Alignment(
            horizontal="center",
            vertical="center",
            wrap_text=True,
        )
        cell.border = THIN_BORDER
    ws.row_dimensions[start_row].height = 30

    for row_index, values in enumerate(rows, start=start_row + 1):
        for col_index, value in enumerate(values, start=1):
            cell = ws.cell(row_index, col_index, value)
            cell.font = body_font(9)
            cell.alignment = Alignment(
                vertical="top",
                horizontal="center" if col_index in center_cols else "left",
                wrap_text=True,
            )
            cell.border = THIN_BORDER
            if row_index % 2 == 0:
                cell.fill = solid_fill("F9FAF8")
            if col_index in number_formats:
                cell.number_format = number_formats[col_index]
        if status_col is not None and status_col <= len(values):
            fill = status_fill(str(values[status_col - 1]))
            if fill is not None:
                ws.cell(row_index, status_col).fill = fill
        ws.row_dimensions[row_index].height = 32

    end_row = start_row + len(rows)
    end_col = len(headers)
    ws.auto_filter.ref = (
        f"A{start_row}:{get_column_letter(end_col)}{end_row}"
        if table_name is None
        else ws.auto_filter.ref
    )
    if freeze:
        ws.freeze_panes = f"A{start_row + 1}"

    if table_name and rows:
        table_ref = f"A{start_row}:{get_column_letter(end_col)}{end_row}"
        table = Table(displayName=table_name, ref=table_ref)
        table.tableStyleInfo = TableStyleInfo(
            name="TableStyleMedium2",
            showFirstColumn=False,
            showLastColumn=False,
            showRowStripes=True,
            showColumnStripes=False,
        )
        ws.add_table(table)

    return end_row + 2


def add_note(ws, row: int, text: str, end_col: int = 8) -> int:
    ws.merge_cells(
        start_row=row,
        start_column=1,
        end_row=row,
        end_column=end_col,
    )
    cell = ws.cell(row, 1, text)
    cell.font = body_font(9, color=COLORS["gray"])
    cell.fill = solid_fill(COLORS["paper"])
    cell.alignment = Alignment(vertical="center", wrap_text=True)
    cell.border = THIN_BORDER
    ws.row_dimensions[row].height = 32
    return row + 2


def add_cover(wb: Workbook) -> None:
    ws = wb.active
    ws.title = "00_封面与索引"
    set_sheet_defaults(ws, landscape=False)
    ws.sheet_properties.tabColor = COLORS["deep_teal"]

    for col, width in {
        "A": 18,
        "B": 20,
        "C": 20,
        "D": 20,
        "E": 20,
        "F": 22,
        "G": 18,
        "H": 18,
    }.items():
        ws.column_dimensions[col].width = width

    ws.merge_cells("A1:H4")
    title = ws["A1"]
    title.value = "《逆岁：四契》\n游戏策划案与制作台账"
    title.font = title_font(28, COLORS["white"])
    title.fill = solid_fill(COLORS["deep_teal"])
    title.alignment = Alignment(horizontal="center", vertical="center")
    for row in range(1, 5):
        ws.row_dimensions[row].height = 34

    ws.merge_cells("A6:H6")
    subtitle = ws["A6"]
    subtitle.value = "2D 横版剧情动作游戏｜Godot 4.7｜中国神话民俗像素风"
    subtitle.font = title_font(13, COLORS["gold"])
    subtitle.fill = solid_fill(COLORS["paper"])
    subtitle.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[6].height = 32

    info = [
        ("文档版本", "v1.7"),
        ("策划基线", "2026-10-27"),
        ("当前阶段", "四幕可玩 Demo 内容重构"),
        ("主方案", "四象面具＋五室关卡＋岁髓岁灯"),
    ]
    for index, (label, value) in enumerate(info, start=8):
        ws.cell(index, 1, label)
        ws.merge_cells(start_row=index, start_column=2, end_row=index, end_column=3)
        ws.cell(index, 2, value)
        for col in range(1, 4):
            cell = ws.cell(index, col)
            cell.border = THIN_BORDER
            cell.alignment = Alignment(vertical="center", wrap_text=True)
            cell.font = body_font(10, bold=(col == 1))
            cell.fill = solid_fill(COLORS["cream"] if col == 1 else COLORS["white"])
        ws.row_dimensions[index].height = 25

    if REFERENCE_IMAGE.exists():
        image = XLImage(str(REFERENCE_IMAGE))
        image.width = 430
        image.height = 260
        ws.add_image(image, "D7")

    directory = [
        ("01_当前决议", "本轮确认的五室、岁髓、技能与装配规则"),
        ("02_项目概览", "产品定义、卖点、支柱、目标与非目标"),
        ("03_核心循环", "探索、战斗、成长、Boss 与重试闭环"),
        ("04_世界观叙事", "停岁、岁契、四象与四幕剧情结构"),
        ("05_五室关卡", "普通房、小 Boss、岁灯、回响房与大 Boss"),
        ("06_敌兵与小Boss", "四幕普通敌人和精英定位"),
        ("07_岁髓与岁灯", "货币产出、生命、攻击与成长规则"),
        ("08_主动技能", "回锋、契灵弹、天雷阵及两级成长"),
        ("09_四象Boss", "白虎、朱雀、玄武、青龙机制与数值"),
        ("10_面具系统", "四象面具被动、主动与战斗定位"),
        ("11_战斗手感", "移动、跳跃、攻击、闪身、反馈参数"),
        ("12_UI剧情存档", "输入、剧情、暂停、检查点与自动存档"),
        ("13_美术音频", "美术规范、动画资产与音频方向"),
        ("14_技术架构", "Godot 模块职责、事件与数据合同"),
        ("15_生产验收", "生产范围、里程碑、验收和剩余工作"),
        ("16_风险待决", "设计、制作、平衡与工程风险"),
        ("17_每日更新", "按日整理需求、修正、实现与验证记录"),
    ]
    row = 22
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=3)
    heading = ws.cell(row, 1, "工作簿目录")
    heading.font = title_font(12, COLORS["white"])
    heading.fill = solid_fill(COLORS["teal"])
    heading.alignment = Alignment(vertical="center")
    row += 1
    for sheet_name, description in directory:
        ws.cell(row, 1, sheet_name)
        ws.cell(row, 1).hyperlink = f"#'{sheet_name}'!A1"
        ws.cell(row, 1).font = body_font(9, bold=True, color=COLORS["blue"])
        ws.cell(row, 1).border = THIN_BORDER
        ws.merge_cells(start_row=row, start_column=2, end_row=row, end_column=3)
        ws.cell(row, 2, description)
        ws.cell(row, 2).font = body_font(9)
        ws.cell(row, 2).alignment = Alignment(vertical="center", wrap_text=True)
        for col in range(1, 4):
            ws.cell(row, col).border = THIN_BORDER
        row += 1

    row += 1
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=3)
    legend = ws.cell(row, 1, "状态图例：绿色＝已完成/通过；黄色＝已确认待制作；蓝色＝验证中；红色＝风险/待决")
    legend.font = body_font(9, color=COLORS["gray"])
    legend.fill = solid_fill(COLORS["paper"])
    legend.alignment = Alignment(vertical="center", wrap_text=True)
    ws.row_dimensions[row].height = 34


def add_decisions_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("01_当前决议")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["gold"]
    row = add_heading(
        ws,
        "当前设计决议",
        "本页为本轮策划基线。五室、岁髓岁灯与主动技能属于已确认设计，尚未进入代码实现。",
        7,
    )
    rows = [
        [1, "关卡结构", "每一幕统一为：前庭房→小Boss房→岁灯房→回响房→大Boss房。", "关卡/战斗/存档", "已确认待制作", "战斗房进入封门，清场开门。"],
        [2, "前庭房敌人", "4 名普通敌人，采用 2＋2 两波。", "关卡/战斗节奏", "已确认待制作", "相较原计划增加 2 名。"],
        [3, "回响房敌人", "5 名普通敌人；第四幕 6 名。", "关卡/战斗节奏", "已确认待制作", "采用 2＋3，第四幕 3＋3。"],
        [4, "小Boss", "1 名精英，短血条、单阶段、复用现有敌人骨架并增加 1 个精英招式。", "敌人/美术/程序", "已确认待制作", "不制作第二套完整 Boss 规格。"],
        [5, "岁髓产出", "普通敌人 1 点，小Boss 2 点；清空房间时结算。", "资源/存档", "已确认待制作", "敌人不刷新，房间奖励只结算一次。"],
        [6, "续命", "3 点恢复 1 生命；5 点增加 1 最大生命。", "成长/平衡", "已确认待制作", "不设上限；增加最大生命不自动回血。"],
        [7, "砺锋", "5 点增加 1 基础攻击力。", "成长/平衡", "已确认待制作", "不设上限；白虎倍率仍按乘法计算。"],
        [8, "技能收集", "可学习多个主动技能，技能最高两级；同时只能装配一个。", "成长/UI/存档", "已确认待制作", "在岁灯房切换装配，不消耗岁髓。"],
        [9, "技能费用", "学习费用为3/6/9；升到二级费用分别为3/6/9。", "成长/平衡", "已确认待制作", "品质与功能并列决定价值。"],
        [10, "主动技能键", "F 使用当前装配技能；E 切换面具，Q 面具技能，Shift 闪身。", "输入/UI", "已确认待制作", "避免与现有按键冲突。"],
        [11, "三个技能", "回锋、契灵弹、天雷阵。", "战斗/美术/程序", "已确认待制作", "契灵弹近似雷球；天雷阵近似玄武雷击。"],
        [12, "岁灯复用", "岁灯房可反复进入消费；回响房清空后可返回岁灯再挑战大Boss。", "关卡/存档", "已确认待制作", "避免回响房岁髓在Boss前无法使用。"],
    ]
    row = write_table(
        ws,
        row,
        ["序号", "决策项", "当前确定内容", "影响范围", "状态", "设计与实现备注"],
        rows,
        [7, 16, 51, 20, 16, 42],
        table_name="CurrentDecisions",
        freeze=True,
        status_col=5,
        center_cols={1},
    )
    add_note(
        ws,
        row,
        "版本边界：v1.6 Word 立项报告保留为历史基线；v1.7 起以本工作簿的当前决议、岁灯和主动技能页为准。",
        6,
    )


def add_overview_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("02_项目概览")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["teal"]
    row = add_heading(
        ws,
        "项目概览",
        "产品定义、设计支柱、目标玩家与非目标。",
        6,
    )
    rows = [
        ["概念", "一句话概念", "拾契人砚穿越停岁的国土，挑战四象神兽、取得面具，并决定旧岁契是否应继续以牺牲维持。", "已确认"],
        ["类型", "产品类型", "2D 横版动作、Boss 学习、线性剧情、轻量成长。", "已确认"],
        ["平台", "目标平台", "Windows 桌面优先，60 FPS；其他平台待定。", "已确认"],
        ["时长", "单周目", "Demo 当前为四幕；完整版目标 4–6 小时。", "已规划"],
        ["玩家", "目标玩家", "喜欢横版动作、清晰预警、Boss 读招与短篇中国神话叙事的玩家。", "已确认"],
        ["卖点", "核心卖点", "四象面具改变战斗解法；五室关卡形成战斗—精英—选择—验证—Boss的高潮结构。", "已确认"],
        ["支柱1", "读招重于数值", "失败必须能归因于预警、碰撞、走位和决策。", "已确认"],
        ["支柱2", "面具改变选择", "每张面具提供不同解法，不把玩家锁死在单一流派。", "已确认"],
        ["支柱3", "神话服务人物", "文化元素落在誓约、行为、场景与人物选择中，而非符号拼贴。", "已确认"],
        ["支柱4", "胜利带来承接", "Boss 面具同时是力量与未完成誓愿；成长必须形成代价与选择。", "已确认"],
        ["非目标1", "不做开放世界", "不改为开放世界、随机地牢、Roguelite 或刷装备游戏。", "已确认"],
        ["非目标2", "不做复杂技能树", "主动技能只做三个、两级、单装配，避免操作和策划复杂度失控。", "已确认"],
        ["非目标3", "不做面具硬门槛", "所有大Boss仍必须以基础剑击、走位、闪身和现有面具能力可通关。", "已确认"],
        ["视觉", "视觉关键词", "古拙、克制、像素、寒白、黛青、赭红、青铜、漆木、傩面、符纸、风雪留白。", "已确认"],
    ]
    write_table(
        ws,
        row,
        ["分类", "字段", "内容", "状态"],
        rows,
        [16, 22, 86, 14],
        table_name="ProjectOverview",
        freeze=True,
        status_col=4,
    )


def add_loop_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("03_核心循环")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["jade"]
    row = add_heading(
        ws,
        "核心循环",
        "从单次交锋到整幕推进，明确玩家行为、系统反馈和成长节奏。",
        7,
    )
    rows = [
        ["秒级循环", "观察", "读取Boss/敌人待机、预警、朝向和地形。", "预警动作、音效、独立危险色。", "让失败可学习。"],
        ["秒级循环", "决策", "攻击、闪身、切换面具、使用面具Q技或主动技能F。", "输入反馈、冷却、资源变化。", "制造攻守转换。"],
        ["秒级循环", "执行", "挥剑、Shift闪身、Q面具技、F主动技。", "动画、碰撞、命中停顿、音效。", "保持在现有操作骨架内扩展。"],
        ["秒级循环", "结算", "伤害、击退、灼烧、格挡、契息、Boss血量变化。", "HUD、受击表现、反馈音。", "结果与动作一致。"],
        ["房间循环", "前庭房", "4名普通敌人分两波。", "清场开门，结算岁髓。", "热身与消耗生命。"],
        ["房间循环", "小Boss房", "单阶段精英战。", "精英血条、额外2岁髓、岁灯门开启。", "形成第一次强度峰值。"],
        ["房间循环", "岁灯房", "使用岁髓恢复、提高生命/攻击、学习/升级/装配技能。", "自动保存、角色成长和技能配置。", "让有限资源形成构筑选择。"],
        ["房间循环", "回响房", "5名敌人，第四幕6名。", "第二波压力、清场开启大Boss门。", "验证岁灯成长是否正确。"],
        ["房间循环", "大Boss房", "四象Boss战。", "面具奖励、胜利剧情、下一幕。", "整幕高潮与叙事兑现。"],
        ["整幕循环", "进入新幕", "阅读剧情、适应新场景与新敌人变体。", "恢复生命、保留面具与成长。", "重置场景节奏。"],
        ["整幕循环", "积累", "清房获取岁髓，决定是否在岁灯集中消费。", "岁髓跨幕保留，敌人不刷新。", "将风险转化为成长。"],
        ["整幕循环", "构筑", "生命、最大生命、攻击、主动技能形成路线。", "资源有限、技能最高两级。", "避免单局内全能化。"],
        ["整幕循环", "挑战", "携构筑挑战四象。", "胜利获得对应面具。", "把面具和关卡主题闭环。"],
    ]
    write_table(
        ws,
        row,
        ["循环层级", "阶段", "玩家/系统行为", "反馈", "设计目的"],
        rows,
        [16, 18, 62, 48, 34],
        table_name="CoreLoops",
        freeze=True,
    )


def add_narrative_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("04_世界观叙事")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["blue"]
    row = add_heading(
        ws,
        "世界观与剧情结构",
        "停岁灾厄、四象岁契、核心人物与四幕叙事推进。",
        8,
    )
    row = write_section(ws, row, "世界规则与术语", 8)
    terms = [
        ["停岁", "四季停止流转的灾厄：永冬、凝河、亡魂迷途、活人遗忘节令。", "世界总冲突"],
        ["岁契", "先民与四象订立的护世契约，规定四兽镇守方位并可被抽取岁髓。", "旧秩序的合法性来源"],
        ["岁髓", "维持旧岁契的生命与记忆精华；当前版本同时作为普通敌人奖励货币。", "叙事资源与玩法资源统一"],
        ["岁庭", "记录、执行和维护岁契的世俗机构。", "幕后规则执行者"],
        ["拾契人", "替亡者送信、为面具寻找继承者的行者。玩家为拾契人·砚。", "主角身份"],
        ["面具", "击败四象后获得的力量载体，承载其元素、誓愿与未完成的守护。", "战斗成长核心"],
        ["逆岁", "借取被封存的时间、强行改变岁序的行为。", "主题与危险力量"],
    ]
    row = write_table(
        ws,
        row,
        ["术语", "定义", "叙事用途"],
        terms,
        [18, 92, 34],
        table_name="WorldTerms",
    )
    row = write_section(ws, row, "四幕剧情结构", 8)
    acts = [
        ["第一幕·金契", "虎踞霜关", "白虎", "岁庭命砚调查山契失效；白虎在阻止山崩与兽潮。", "获得白虎面具；面具是誓愿的承接。"],
        ["第二幕·火契", "赤羽烬原", "朱雀", "冻结火种与岁庭符印；朱雀保护尚未熄灭的夏火。", "获得朱雀面具；发现岁庭在抽取四象力量。"],
        ["第三幕·水契", "玄渊冰河", "玄武", "凝河失控；玄武以身体困住洪水与旧契。", "获得玄武面具；确认停岁来自旧契维护机制。"],
        ["第四幕·木契", "青龙岁庭", "青龙", "青龙试图把世界固定在灾难发生前；砚反驳保护不等于替众生决定。", "获得青龙面具，击败旧岁契执行者。"],
        ["归岁", "停岁裂隙", "—", "砚以四象面具重新承接守护责任，结束旧契的永久监禁。", "四季恢复流动，世界承担未知与自由。"],
    ]
    write_table(
        ws,
        row,
        ["幕", "场景", "Boss", "核心事件", "奖励/转折"],
        acts,
        [18, 20, 14, 68, 50],
        table_name="NarrativeActs",
    )


def add_room_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("05_五室关卡")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["red"]
    row = add_heading(
        ws,
        "五室关卡结构",
        "每一幕固定为五室。前庭4敌、小Boss1名、回响房5敌（第四幕6敌）。战斗房清场前后门封禁。",
        9,
    )
    rows = [
        ["第一幕", 1, "前庭房", "4 狼", "2＋2", 4, "进入封门", "热身、教学、消耗生命", "已确认待制作"],
        ["第一幕", 2, "守契兽房", "霜牙狼精英 ×1", "单体", 2, "精英战", "同骨架、单阶段、一个额外招式", "已确认待制作"],
        ["第一幕", 3, "岁灯房", "无战斗", "安全区", 0, "不封门", "岁髓消费、技能装配、存档", "已确认待制作"],
        ["第一幕", 4, "回响房", "5 狼", "2＋3", 5, "进入封门", "验证岁灯构筑", "已确认待制作"],
        ["第一幕", 5, "神兽主殿", "白虎", "Boss", 0, "Boss门", "面具奖励与胜利剧情", "已实现"],
        ["第二幕", 1, "前庭房", "4 熊", "2＋2", 4, "进入封门", "热身、消耗生命", "已确认待制作"],
        ["第二幕", 2, "守契兽房", "镇山熊 ×1", "单体", 2, "精英战", "强化近身压迫", "已确认待制作"],
        ["第二幕", 3, "岁灯房", "无战斗", "安全区", 0, "不封门", "成长与装配", "已确认待制作"],
        ["第二幕", 4, "回响房", "5 熊", "2＋3", 5, "进入封门", "验证构筑", "已确认待制作"],
        ["第二幕", 5, "神兽主殿", "朱雀", "Boss", 0, "Boss门", "面具与剧情", "已实现"],
        ["第三幕", 1, "前庭房", "4 麋鹿", "2＋2", 4, "进入封门", "热身", "已确认待制作"],
        ["第三幕", 2, "守契兽房", "雷角麋 ×1", "单体", 2, "精英战", "雷电/冲撞组合", "已确认待制作"],
        ["第三幕", 3, "岁灯房", "无战斗", "安全区", 0, "不封门", "成长与装配", "已确认待制作"],
        ["第三幕", 4, "回响房", "5 麋鹿", "2＋3", 5, "进入封门", "验证构筑", "已确认待制作"],
        ["第三幕", 5, "神兽主殿", "玄武", "Boss", 0, "Boss门", "面具与剧情", "已实现"],
        ["第四幕", 1, "前庭房", "4 守卫", "2＋2", 4, "进入封门", "热身", "已确认待制作"],
        ["第四幕", 2, "守契兽房", "执契尉 ×1", "单体", 2, "精英战", "守卫长强化", "已确认待制作"],
        ["第四幕", 3, "岁灯房", "无战斗", "安全区", 0, "不封门", "最终构筑与装配", "已确认待制作"],
        ["第四幕", 4, "回响房", "6 守卫", "3＋3", 6, "进入封门", "最终验证", "已确认待制作"],
        ["第四幕", 5, "神兽主殿", "青龙", "Boss", 0, "Boss门", "面具与终局", "已实现"],
    ]
    row = write_table(
        ws,
        row,
        ["幕", "室序", "房间", "敌人", "波次", "清房岁髓", "门禁", "节奏目标", "状态"],
        rows,
        [12, 8, 18, 24, 12, 12, 14, 48, 16],
        table_name="FiveRoomFlow",
        freeze=True,
        status_col=9,
        center_cols={2, 5, 6},
    )
    add_note(
        ws,
        row,
        "经济校验：前庭4＋小Boss2＝岁灯前6点；回响房5点（第四幕6点）结转下一幕。全清一周目约45点岁髓。",
        9,
    )


def add_enemy_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("06_敌兵与小Boss")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["red"]
    row = add_heading(
        ws,
        "普通敌人与小Boss",
        "小Boss复用普通敌人动作骨架，使用精英血条、缩放与一到两个专属表现，控制美术与程序成本。",
        8,
    )
    rows = [
        ["第一幕", "狼", "冲撞/扑击", "高速横向追击与技能预警。", "霜牙狼", "提高移动压迫，增加短距二次扑击。", "移动/攻击动画已接入", "精英变体待制作"],
        ["第二幕", "熊", "重体压迫/范围冲击", "近身威胁高，适合作为前庭房节奏锚点。", "镇山熊", "落地震击或短距离扑击；保持单阶段。", "攻击/移动动画已接入", "精英变体待制作"],
        ["第三幕", "麋鹿", "雷电/盾/地震", "复合机制敌人，需更清晰的预警与视觉区分。", "雷角麋", "强化雷电轨迹或盾破后的反扑。", "攻击/移动动画已接入", "精英变体待制作"],
        ["第四幕", "守卫", "剑光/追击", "现有持剑守卫已具备移动、攻击、受击与死亡表现。", "执契尉", "增加一次连续剑光或前压步；不得遮挡Boss招式。", "移动/攻击/受击/死亡已接入", "精英变体待制作"],
    ]
    row = write_table(
        ws,
        row,
        ["幕", "普通敌人", "基础机制", "战斗作用", "小Boss", "精英变化", "现有资产", "状态"],
        rows,
        [12, 14, 28, 46, 16, 44, 30, 18],
        table_name="EnemyRoster",
        freeze=True,
        status_col=8,
    )
    row = write_section(ws, row, "小Boss设计约束", 8)
    constraints = [
        ["生命", "普通敌人2–3倍，约60–90秒战斗。"],
        ["阶段", "单阶段，不设置半血剧情或全屏转场。"],
        ["攻击", "保留基础攻击，新增1个高辨识精英招式。"],
        ["反馈", "使用短精英血条；死亡、受击和攻击表现必须完整。"],
        ["资产", "优先复用原骨架和帧，只做配色、轮廓、附加特效。"],
    ]
    write_table(
        ws,
        row,
        ["维度", "规则"],
        constraints,
        [18, 104],
        table_name="MiniBossRules",
    )


def add_marrow_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("07_岁髓与岁灯")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["gold"]
    row = add_heading(
        ws,
        "岁髓与岁灯",
        "岁髓是本轮确认的核心奖励货币。岁灯为可反复消费的安全房，不设置生命、最大生命和攻击力全局上限。",
        8,
    )
    economy = [
        ["产出", "普通敌人", "每名1点；清空房间时结算。", "无单次上限", "敌人不刷新"],
        ["产出", "小Boss", "每名2点。", "每名一次", "击败后开门"],
        ["产出", "回响房", "5点；第四幕6点。", "每幕一次", "结算后结转"],
        ["总量", "全清一周目", "约45点。", "有限资源", "4幕：11＋11＋11＋12"],
        ["续命", "恢复生命", "3点恢复1生命；可重复购买。", "受缺失生命限制", "满血不可购买"],
        ["续命", "增加最大生命", "5点增加1最大生命；不自动回血。", "无上限", "可在同一岁灯重复购买"],
        ["砺锋", "增加基础攻击", "5点增加1基础攻击；可重复购买。", "无上限", "白虎倍率按乘法结算"],
        ["悟式", "学习技能", "回锋3；契灵弹6；天雷阵9。", "每个技能一次", "可拥有多个技能"],
        ["悟式", "升级技能", "升到二级分别消耗3/6/9。", "技能最高二级", "升级费用等于该技能学习费用"],
        ["装配", "切换技能", "岁灯房内免费切换已拥有技能。", "同时装配1个", "战斗中不能更换"],
    ]
    row = write_table(
        ws,
        row,
        ["分类", "项目", "规则/数值", "上限", "备注"],
        economy,
        [14, 20, 58, 20, 40],
        table_name="MarrowEconomy",
        freeze=True,
    )
    row = write_section(ws, row, "岁灯交互流程", 8)
    flow = [
        ["1", "进入", "玩家进入无战斗的岁灯房，附近敌人已经清空。"],
        ["2", "浏览", "界面显示当前岁髓、当前生命/最大生命、基础攻击、技能收藏与装配状态。"],
        ["3", "消费", "可重复购买续命、最大生命、砺锋；学习/升级受技能二级上限约束。"],
        ["4", "装配", "从已拥有技能中选择一个装备到F键；切换免费。"],
        ["5", "保存", "关闭界面或离开岁灯时自动保存资源、属性和技能配置。"],
        ["6", "回访", "回响房清空后可返回岁灯继续消费，再进入大Boss房；已清房间不重新结算奖励。"],
    ]
    write_table(
        ws,
        row,
        ["步骤", "阶段", "玩家体验"],
        flow,
        [10, 18, 104],
        table_name="RestFlow",
        center_cols={1},
    )


def add_skill_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("08_主动技能")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["gold"]
    row = add_heading(
        ws,
        "主动技能系统",
        "F键释放当前装配技能；技能可多学，最高两级，同时只能装配一个。伤害使用当前基础攻击，但不吃白虎普通攻击倍率。",
        11,
    )
    rows = [
        ["回锋", "凡契", 3, 3, "F", 6.0, "向前宽扇形剑势，1.75倍基础攻击。", "伤害2.25倍，范围+15%，冷却5.5秒。", "近战爆发", "已确认待制作"],
        ["契灵弹", "灵契", 6, 6, "F", 8.0, "发射1枚直线弹，1.5倍基础攻击，速度520，距离约600。", "连续2枚，间隔0.18秒，每枚1.25倍基础攻击。", "远程补伤/处理高台敌人", "已确认待制作"],
        ["天雷阵", "神契", 9, 9, "F", 18.0, "0.6秒预警后3束不相邻雷电，每束1.5倍基础攻击。", "两轮，每轮3束，间隔0.6秒；每名敌人每轮最多中1束。", "大范围清场与安全窗口", "已确认待制作"],
    ]
    row = write_table(
        ws,
        row,
        ["技能", "品质", "学习", "升二级", "按键", "冷却(秒)", "一级效果", "二级效果", "定位", "状态"],
        rows,
        [14, 12, 10, 10, 8, 12, 48, 54, 26, 16],
        table_name="ActiveSkills",
        freeze=True,
        status_col=10,
        center_cols={2, 3, 4, 5, 6},
    )
    row = write_section(ws, row, "统一规则", 10)
    rules = [
        ["成长关系", "技能伤害按当前基础攻击力计算，享受砺锋；不享受白虎普通剑击×2、朱雀灼烧。"],
        ["无敌", "所有主动技能不提供无敌，不替代Shift闪身。"],
        ["Boss交互", "不打断Boss已开始的预警或释放，不造成Boss眩晕。"],
        ["冷却", "各技能独立冷却；未装配技能不显示冷却，切换后从可用状态开始。"],
        ["切换", "只能在岁灯房切换装配；Boss战和暂停菜单中不可更换。"],
        ["美术", "回锋复用剑击框架；契灵弹复用雷球碰撞并重做玩家色；天雷阵复用雷电束框架并重做青金雷纹。"],
    ]
    write_table(
        ws,
        row,
        ["规则", "说明"],
        rules,
        [18, 106],
        table_name="ActiveSkillRules",
    )


def add_boss_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("09_四象Boss")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["red"]
    row = add_heading(
        ws,
        "四象大Boss",
        "当前实现状态与最新平衡值。四象保留现有机理骨架，逐步替换为中国神话行为和专属表现。",
        10,
    )
    rows = [
        ["白虎", 15, "重体压迫、扑击、地面冲击", "低姿态巡逻、近身压迫、死亡演出", "扑击后窗口", "已接入模型、攻击/移动动画；专属阶段待深化", "已实现"],
        ["朱雀", 30, "高速移动、火球、空中火羽", "可战斗开始即空中施法；技能冷却2秒；火球体积2.16倍、速度570", "空中攻击落地窗口", "移动、攻击、空中施法已接入", "已实现"],
        ["玄武", 90, "壳甲、雷电束雨、地震", "雷击6秒每0.6秒三束；结束后10秒冷却；地震独立触发", "护盾破碎/潮裂后窗口", "攻击与施法循环已接入", "已实现"],
        ["青龙", 110, "追击、剑光、黑水、紫雷龙息、逆鳞扑杀", "半血觉醒、颜色变紫、剑光冷却2/1.5秒、雷球速度600", "剑光后停顿、扑杀落地", "移动/攻击/空中/扑杀动画已接入；阶段机制继续打磨", "已实现"],
    ]
    row = write_table(
        ws,
        row,
        ["Boss", "生命", "核心威胁", "当前战斗规则", "主要弱点", "资产与机制状态", "完成状态"],
        rows,
        [12, 10, 36, 64, 26, 42, 16],
        table_name="FourSymbolsBosses",
        freeze=True,
        status_col=7,
        center_cols={2},
    )
    row = write_section(ws, row, "五室结构中的Boss定位", 10)
    notes = [
        ["小Boss", "短时、单阶段、一个精英招式；为岁灯房提供资源与节奏峰值。"],
        ["大Boss", "2–4分钟；保留四象的招式主题与阶段变化，负责面具奖励和叙事转折。"],
        ["风险控制", "不能在制作小Boss时提前消耗大Boss的独特机制与演出预算。"],
    ]
    write_table(
        ws,
        row,
        ["Boss层级", "设计边界"],
        notes,
        [18, 106],
        table_name="BossHierarchy",
    )


def add_mask_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("10_面具系统")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["blue"]
    row = add_heading(
        ws,
        "四象面具系统",
        "E切换面具，Q使用当前面具主动技。面具跨幕保留，冷却按面具独立保存；本轮不改四张面具基础效果。",
        8,
    )
    rows = [
        ["白虎面具", "白虎", "普通剑击伤害×2，范围在基础1.5倍上再×2.0，最终范围×3。", "无", "范围压制与高伤害", "已实现"],
        ["朱雀面具", "朱雀", "攻击附加火焰斩击；命中灼烧2秒，每0.5秒伤害并闪红。", "无", "持续伤害与连续进攻", "已实现"],
        ["玄武面具", "玄武", "自动格挡下一次攻击，冷却10秒；仅装备时显示护盾。", "Q龙栖：恢复1生命，冷却15秒。", "容错与有限续航", "已实现"],
        ["青龙面具", "青龙", "弱点标记/契息资源方向的设计仍在收敛。", "Q照岁类主动技方向待最终锁定。", "弱点窗口与资源回收", "部分实现/待深化"],
    ]
    write_table(
        ws,
        row,
        ["面具", "来源", "被动", "主动", "战斗定位", "状态"],
        rows,
        [16, 12, 62, 36, 32, 18],
        table_name="MaskSystem",
        freeze=True,
        status_col=6,
    )


def add_combat_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("11_战斗手感")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["teal"]
    row = add_heading(
        ws,
        "战斗与手感参数",
        "以当前 Godot 实现为基线。参数是可测试的首轮目标，不是最终锁值。",
        7,
    )
    rows = [
        ["移动", "地面最高速度", "300 px/s", "已实现", "沿用现有节奏"],
        ["跳跃", "跳跃初速度", "-600 px/s", "已实现", "当前 Player 常量"],
        ["跳跃", "土狼时间", "0.10 秒", "已实现", "离开平台后短暂可跳"],
        ["跳跃", "跳跃缓冲", "0.12 秒", "已实现", "落地前输入缓存"],
        ["跳跃", "松键倍率", "0.45", "已实现", "可变跳高"],
        ["攻击", "基础攻击", "8", "已实现", "砺锋每级+1"],
        ["攻击", "基础范围倍率", "1.5×", "已实现", "扇形攻击"],
        ["攻击", "攻击冷却", "0.8 秒", "已实现", "共享攻击间隔"],
        ["闪身", "速度", "940 px/s", "已实现", "Shift触发"],
        ["闪身", "持续时间", "0.15 秒", "已实现", "仅位移，不无敌"],
        ["闪身", "冷却", "0.3 秒", "已实现", "受击立即中断"],
        ["受击", "无敌时间", "1.5 秒", "已实现", "普通受击保护"],
        ["生命", "默认上限", "5", "已实现", "四幕统一"],
        ["反馈", "命中停顿", "普通3–4帧；重击5–7帧；破防7–9帧", "目标/部分实现", "需持续调优"],
        ["反馈", "震屏", "普通1–2px；格挡2–3px；Boss破防3–4px", "目标", "应支持关闭/减弱"],
        ["镜头", "水平前瞻", "60 px", "目标", "与 Camera2D 平滑配合"],
    ]
    write_table(
        ws,
        row,
        ["类别", "参数", "首轮值", "实现状态", "备注"],
        rows,
        [14, 26, 34, 18, 54],
        table_name="CombatFeel",
        freeze=True,
        status_col=4,
    )


def add_ui_save_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("12_UI剧情存档")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["blue"]
    row = add_heading(
        ws,
        "UI、剧情与存档",
        "覆盖输入指南、剧情对白、暂停菜单、设置、检查点、Continue 与自动存档。",
        8,
    )
    rows = [
        ["输入指南", "中文标题与说明；明确E切换面具、Q面具技能；本轮新增F主动技能。", "开场/暂停", "不随战役存档", "部分已实现"],
        ["剧情对白", "玩家立绘固定左侧并朝右；图片已镜像；阿禾、青蘅、墨川剧情已删除。", "开场/胜利/半血", "剧情进度由关卡状态控制", "已实现"],
        ["暂停菜单", "Esc：继续、当前检查点重试、设置、返回标题、退出。", "活跃战斗", "不清除存档", "已实现"],
        ["设置", "主音量、全屏；立即应用并持久化。", "暂停/设置页", "user://settings.json", "已实现"],
        ["幕检查点", "开场剧情完成后保存当前幕。", "进入关卡", "campaign_autosave.json", "已实现"],
        ["Boss检查点", "跨过Boss门后保存并恢复门后位置。", "Boss门", "campaign_autosave.json", "已实现"],
        ["岁灯检查点", "岁灯消费/装配后保存资源和技能；回响房清空后保留岁灯回访。", "离开岁灯", "需扩展存档schema", "已确认待制作"],
        ["Continue", "标题页只有有效存档时显示，恢复幕、检查点、面具与位置。", "启动/标题", "JSON + .bak 回退", "已实现"],
        ["新游戏", "清除旧自动存档并重置面具、检查点、岁髓、技能。", "标题", "删除 campaign_autosave", "已实现/待扩展"],
        ["HUD", "生命、面具、契息、Q冷却、岁髓、F技能与冷却。", "游戏中", "岁髓/技能需新增", "部分待制作"],
    ]
    write_table(
        ws,
        row,
        ["模块", "当前内容", "触发", "存档位置/合同", "状态"],
        rows,
        [18, 78, 24, 36, 18],
        table_name="UiStorySave",
        freeze=True,
        status_col=5,
    )


def add_art_audio_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("13_美术音频")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["jade"]
    row = add_heading(
        ws,
        "美术与音频规范",
        "中国神话民俗像素风；统一剪影、元素色、锚点和可读性。",
        7,
    )
    rows = [
        ["色彩", "环境", "寒白、灰青、墨蓝；表达停岁与冻土。", "已确认"],
        ["色彩", "神性", "青铜绿、暗金；岁庭、契印、面具。", "已确认"],
        ["色彩", "危险", "朱砂红、紫黑；不可格挡与逆岁力量。", "已确认"],
        ["白虎", "美术识别", "雪白、黑、青、金；金气、雪尘、扑击残影。", "模型与攻击/移动已接入"],
        ["朱雀", "美术识别", "朱红、橙黄、金；火羽、余烬、热浪。", "移动/攻击/空中动画已接入"],
        ["玄武", "美术识别", "墨绿、青蓝、石灰；水纹、甲壳反光、雷雨。", "攻击/移动/施法已接入"],
        ["青龙", "美术识别", "青绿、浅米、碧蓝；觉醒后深紫，战斗结束恢复。", "移动/攻击/空中/扑杀已接入"],
        ["角色规格", "玩家", "256×256透明PNG，脚底中心锚点；未来待补受伤/死亡/技能帧。", "部分完成"],
        ["敌人规格", "普通/精英", "优先128×128或既有256帧合同；动作方向一致。", "部分完成"],
        ["特效", "技能一致性", "契灵弹使用玩家青金弹体；天雷阵青金雷纹；不直接复用Boss紫色素材。", "待制作"],
        ["音乐", "主题", "古琴、笛、箫、埙、鼓、钟磬与弦乐现代混合。", "规划"],
        ["音效", "优先级", "格挡/弱点>普通命中>受击>背景粒子。", "部分实现"],
    ]
    write_table(
        ws,
        row,
        ["类别", "对象", "规范/现状", "状态"],
        rows,
        [16, 22, 82, 26],
        table_name="ArtAudio",
        freeze=True,
        status_col=4,
    )


def add_tech_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("14_技术架构")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["gray"]
    row = add_heading(
        ws,
        "Godot 技术架构",
        "保留现有 CampaignLevel、Player、Boss 与 JSON Story 骨架；本轮新增 Room/Rest/ActiveSkill 为窄接口。",
        7,
    )
    rows = [
        ["main.gd", "标题、序章、四幕、胜败、结局、顶层流程", "关卡切换/Continue", "已实现", "不得承载具体技能逻辑"],
        ["CampaignLevel", "关卡契约、检查点、面具奖励、剧情阶段", "checkpoint_reached/mask_awarded", "已实现", "扩展岁灯与房间状态"],
        ["LevelBase", "通用剧情、HUD、镜头、胜利流程", "prepare/restore/apply masks", "已实现", "新增房间门禁与房间奖励入口"],
        ["Player", "移动、跳跃、攻击、闪身、受击、Q技能", "health/mask/attack", "已实现", "新增F主动技能状态"],
        ["MaskController", "面具解锁、契息、冷却、玄武格挡与龙栖", "state_changed/mask_unlocked", "已实现", "不并入主动技能系统"],
        ["CampaignSave", "版本化JSON自动存档、备份与校验", "SAVE_VERSION=1", "已实现/待升级", "需保存岁髓、岁灯、技能与房间结算"],
        ["Room Coordinator", "房间触发、波次、封门、清场、奖励", "待定义", "待制作", "不要散落在每个敌人脚本"],
        ["Rest Point", "岁髓商店、技能装配、属性成长", "待定义", "待制作", "与DamageAndHealth解耦"],
        ["Active Skill", "F技能、独立冷却、装配与伤害", "待定义", "待制作", "不抢占Q面具技"],
        ["JSON Story", "对白、角色立绘与演出提示", "现有兼容格式", "已实现", "新增字段必须可选"],
        ["测试", "Save/Pause/Masks/Smoke等无头合同", "顺序执行", "持续扩展", "禁止并行启动Godot测试"],
    ]
    write_table(
        ws,
        row,
        ["模块", "职责", "关键合同", "状态", "实现约束"],
        rows,
        [22, 56, 36, 20, 42],
        table_name="TechnicalArchitecture",
        freeze=True,
        status_col=4,
    )


def add_production_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("15_生产验收")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["gold"]
    row = add_heading(
        ws,
        "生产范围与验收",
        "从当前可玩四幕Demo到五室结构落地的工作拆分。完成度为策划估算，随制作更新。",
        8,
    )
    rows = [
        ["A1", "四象版本可玩基线", "四幕流程、面具、Boss、存档、暂停、闪身", "已可运行", 1.0, "已完成"],
        ["A2", "美术与动画基线", "玩家三套动作、四象攻击/移动、守卫动作", "完成第一轮", 0.75, "持续打磨"],
        ["B1", "五室关卡框架", "房间触发、封门、波次、清场结算", "待制作", 0.0, "待制作"],
        ["B2", "普通敌人配置", "前庭4、回响5/6、四幕分组", "待制作", 0.0, "待制作"],
        ["B3", "小Boss变体", "四幕精英配置、血条、招式", "待制作", 0.0, "待制作"],
        ["C1", "岁髓经济", "掉落、结算、跨幕保留、经济校验", "待制作", 0.0, "待制作"],
        ["C2", "岁灯商店", "生命、最大生命、攻击、技能、装配、存档", "待制作", 0.0, "待制作"],
        ["D1", "主动技能", "回锋、契灵弹、天雷阵及两级成长", "待制作", 0.0, "待制作"],
        ["D2", "技能特效", "契灵弹玩家色、天雷阵雷纹、技能音效", "待制作", 0.0, "待制作"],
        ["E1", "存档升级", "岁髓、技能、房间、岁灯、检查点", "待设计实现", 0.0, "待制作"],
        ["E2", "测试", "经济、房间、技能、存档、Continue、重试", "待编写", 0.0, "待制作"],
        ["F1", "平衡试玩", "全清/跳房/不同技能组合/四幕通关", "待执行", 0.0, "待验证"],
    ]
    row = write_table(
        ws,
        row,
        ["编号", "工作包", "交付", "当前进度", "完成度", "状态"],
        rows,
        [10, 24, 62, 20, 12, 18],
        table_name="ProductionPlan",
        freeze=True,
        status_col=6,
        center_cols={1, 4, 5},
        number_formats={5: "0%"},
    )
    ws.conditional_formatting.add(
        f"E{row - len(rows)}:E{row - 2}",
        DataBarRule(start_type="num", start_value=0, end_type="num", end_value=1, color=COLORS["jade"]),
    )
    row = write_section(ws, row, "验收标准", 8)
    acceptance = [
        ["关卡", "五室均能按顺序进入；战斗房封门，清场开门；回响房后能回岁灯。"],
        ["奖励", "每个房间只结算一次岁髓；死亡重试不会重复获取。"],
        ["岁灯", "生命、最大生命、攻击可重复购买；满血时恢复按钮禁用。"],
        ["技能", "可拥有多个技能，最多装配一个；技能最高二级；F冷却正确。"],
        ["Boss", "全部四象仍可在基础剑击、闪身和合法成长条件下击败。"],
        ["存档", "Continue恢复岁髓、属性、技能收藏、装配、房间和岁灯状态。"],
        ["测试", "专项测试与smoke_main顺序通过；无并行Godot进程。"],
    ]
    write_table(
        ws,
        row,
        ["验收域", "必须满足"],
        acceptance,
        [18, 106],
        table_name="AcceptanceCriteria",
    )


def add_risk_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("16_风险待决")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["red"]
    row = add_heading(
        ws,
        "风险与待决事项",
        "按影响、可能性和可执行缓解措施整理。",
        7,
    )
    rows = [
        ["数值滚雪球", "无上限最大生命/攻击使后期Boss明显变简单。", "高", "用45点总岁髓与5点单次成本限制；重点试玩全清路线。"],
        ["治疗性价比", "3点恢复1生命可能在高难Boss前成为必买项。", "中", "记录Boss前平均缺失生命与持有岁髓。"],
        ["技能同质化", "契灵弹和天雷阵复用Boss投射物/雷击会缺少玩家辨识。", "中", "重做玩家色、发射器、落雷纹样与音效。"],
        ["房间疲劳", "4+1+5/6名敌人使每幕战斗变长。", "高", "使用分波、短过渡、环境变化，不做全量同时生成。"],
        ["刷奖励", "死亡、Continue或房间重载可能重复结算岁髓。", "高", "稳定Room ID、清房旗标和检查点事务保存。"],
        ["存档迁移", "现有SAVE_VERSION=1不含岁髓技能。", "高", "升级schema并提供旧档默认迁移。"],
        ["小Boss资产膨胀", "四个小Boss可能演变为四个额外大Boss。", "高", "复用骨架、单阶段、一个精英招式、短血条。"],
        ["技能按键冲突", "F、E、Q、Shift同时存在，需要清晰HUD与教学。", "中", "操作指南单独加入F主动技能。"],
        ["岁灯回访路径", "回响房后返回岁灯可能打断Boss前节奏。", "中", "提供明确图标与短路径；可选但非强制。"],
        ["开放决策", "第五幕、最终幕后Boss与NG+仍未纳入本轮Excel生产范围。", "中", "保留在完整版路线，不与当前四幕Demo混排。"],
    ]
    write_table(
        ws,
        row,
        ["风险", "影响", "等级", "缓解措施"],
        rows,
        [24, 62, 12, 70],
        table_name="RiskRegister",
        freeze=True,
        center_cols={3},
    )


def add_daily_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("17_每日更新")
    set_sheet_defaults(ws)
    ws.sheet_properties.tabColor = COLORS["blue"]
    row = add_heading(
        ws,
        "每日更新记录",
        "依据现有需求记录、实施状态、文档与源文件时间整理。此表区分需求、实现、修正与验证，后续可直接追加。",
        9,
    )
    rows = [
        [date(2026, 10, 24), "策划", "中国神话重构", "将西方王权叙事切换为停岁、四象岁契与拾契人砚。", "世界观/剧情", "GDD v1.6", "已确认", "GDD v1.6", "确立四幕主方案"],
        [date(2026, 10, 24), "美术", "四象参考图", "导入白虎、朱雀、玄武、青龙像素参考图作为美术方向。", "美术/角色", "四象参考图", "已完成", "four-symbols-reference.jpg", "仅作参考，不复用原图像素拆分"],
        [date(2026, 10, 24), "关卡", "Boss归属纠正", "第一幕改为白虎、第二幕改为朱雀，修正前两幕立绘与主题映射。", "关卡/剧情", "Level01–02", "已修正", "implementation-status", ""],
        [date(2026, 10, 24), "战斗", "面具效果重做", "白虎攻击强化；朱雀灼烧；玄武格挡与龙栖形成不同战斗解法。", "面具/战斗", "MaskController/Player", "已实现", "implementation-status", ""],
        [date(2026, 10, 24), "角色", "玩家游戏内模型重制", "新像素模型接入游戏内，对齐碰撞体并新增移动、跳跃、攻击帧。", "玩家/美术/动画", "Player", "已实现", "implementation-status", "剧情立绘保持独立"],
        [date(2026, 10, 25), "剧情", "旧角色清理", "删除阿禾、青蘅、墨川剧情及旧NPC穿帮。", "剧情/场景", "Story JSON/Level", "已完成", "implementation-status", ""],
        [date(2026, 10, 25), "UI", "操作指南中文化", "Controls界面中文分区、中文说明，并突出E切换/Q技能。", "UI/输入", "Control Guide", "已完成", "implementation-status", ""],
        [date(2026, 10, 25), "UI", "对白位置修正", "玩家剧情立绘保持左侧、面朝右，并进行水平镜像。", "剧情/UI", "Story", "已完成", "implementation-status", ""],
        [date(2026, 10, 25), "美术", "Boss动画第一轮", "四象攻击与移动动画接入；朱雀移动方向与头身一致。", "Boss/动画", "Boss scenes", "已实现", "implementation-status", ""],
        [date(2026, 10, 25), "战斗", "碰撞体与缩放", "调整四象与玩家显示比例、碰撞体，青龙受击框扩大。", "战斗/碰撞", "Player/Boss", "已修正", "implementation-status", ""],
        [date(2026, 10, 25), "玩家", "攻击动画舒展", "玩家攻击改为8帧完整蓄势、过顶挥剑与收势，24FPS。", "玩家/动画", "Player", "已实现", "implementation-status", ""],
        [date(2026, 10, 25), "战斗", "Boss血量平衡", "白虎15、朱雀30、玄武90、青龙110；玩家统一5生命。", "数值/战斗", "Boss/Player", "已实现", "implementation-status", ""],
        [date(2026, 10, 26), "战斗", "空中投射物技能", "朱雀焚空火羽、青龙紫雷龙息接入升空施法与透明投射物。", "Boss/技能/动画", "Bird/Dragon", "已实现", "implementation-status", ""],
        [date(2026, 10, 26), "战斗", "朱雀火球替换", "原地震改为朝玩家发射红色火球，体积2.16倍、速度570。", "Boss/投射物", "Bird", "已实现", "implementation-status", ""],
        [date(2026, 10, 26), "战斗", "青龙二阶段循环", "两次剑光、一次黑水、两次剑光、一次雷息；半血觉醒染色。", "Boss/AI/特效", "Dragon", "已实现", "implementation-status", ""],
        [date(2026, 10, 26), "战斗", "逆鳞扑杀", "连续第3次受击后升空锁定并俯冲，接入16帧专用动画。", "Boss/AI/动画", "Dragon", "已实现", "implementation-status", ""],
        [date(2026, 10, 26), "敌人", "第四幕守卫动画", "守卫移动、攻击、受击、死亡表现接入；每次受击均重播反馈。", "敌人/动画", "Guard", "已修正", "implementation-status", ""],
        [date(2026, 10, 26), "战斗", "灼烧反馈", "朱雀灼烧2秒，每0.5秒1伤害；敌人持续闪红。", "战斗/特效", "Player/Burn", "已实现", "implementation-status", ""],
        [date(2026, 10, 26), "QA", "攻击范围与特效一致", "玩家斩击特效半径读取武器实际碰撞距离。", "战斗/反馈", "Player", "已修正", "implementation-status", "白虎倍率单独处理"],
        [date(2026, 10, 27), "存档", "自动存档与Continue", "版本化JSON、临时文件、.bak回退；恢复幕、检查点、面具与位置。", "存档/流程", "CampaignSave/main", "已实现", "implementation-status", ""],
        [date(2026, 10, 27), "存档", "Boss前检查点", "跨过Boss门后保存；死亡重试与Continue恢复门后战斗区。", "检查点/存档", "CampaignLevel/main", "已实现", "implementation-status", ""],
        [date(2026, 10, 27), "UI", "暂停菜单与设置", "Esc暂停、检查点重试、主音量、全屏、返回标题、退出。", "UI/设置", "PauseMenu/GameSettings", "已实现", "implementation-status", ""],
        [date(2026, 10, 27), "手感", "通用闪身", "Shift、940速度、0.15秒、0.3秒冷却；仅位移，不无敌。", "玩家/动画/输入", "Player", "已实现", "implementation-status", "8帧专用动画"],
        [date(2026, 10, 27), "平衡", "白虎面具收敛", "最终范围由3.3倍调整为3倍；保留伤害×2。", "面具/战斗", "Player/HUD", "已实现", "implementation-status", ""],
        [date(2026, 10, 27), "策划", "五室关卡决议", "前庭房→小Boss房→岁灯→回响房→大Boss。", "关卡/节奏", "GDD v1.7", "已确认待制作", "本轮对话", "房间进入封门、清场开门"],
        [date(2026, 10, 27), "策划", "敌人数量增加", "前庭加2至4名；回响房加3至5名，第四幕6名。", "关卡/战斗", "GDD v1.7", "已确认待制作", "本轮对话", "分波生成，避免同屏过载"],
        [date(2026, 10, 27), "策划", "岁髓岁灯规则", "续命3/5；砺锋5；生命与攻击不设上限。", "成长/经济", "GDD v1.7", "已确认待制作", "本轮对话", "总资源由有限敌人数量约束"],
        [date(2026, 10, 27), "策划", "主动技能系统", "技能最高2级；可购买多个，只能装配1个。", "成长/UI/存档", "GDD v1.7", "已确认待制作", "本轮对话", "岁灯房免费切换"],
        [date(2026, 10, 27), "策划", "三技能定型", "回锋、契灵弹、天雷阵；费用3/6/9，升级同价。", "战斗/特效", "GDD v1.7", "已确认待制作", "本轮对话", "F键释放"],
        [date(2026, 10, 27), "文档", "v1.7 Excel策划案", "将GDD、实施状态与最新决议整理为多Sheet工作簿。", "文档/项目管理", "GDD v1.7.xlsx", "已完成", "本次生成", "本项目交付物"],
    ]
    write_table(
        ws,
        row,
        ["日期", "类别", "更新项", "内容摘要", "影响范围", "依据/文件", "状态", "来源", "备注"],
        rows,
        [13, 12, 24, 74, 22, 32, 18, 24, 34],
        table_name="DailyUpdates",
        freeze=True,
        status_col=7,
        center_cols={1},
        number_formats={1: "yyyy-mm-dd"},
    )


def finalize_workbook(wb: Workbook) -> None:
    wb.properties.title = "《逆岁：四契》游戏策划案 v1.7"
    wb.properties.subject = "立项报告、系统设计、五室关卡、岁髓岁灯、主动技能与每日更新"
    wb.properties.creator = "Codex Game Design Workbook"
    wb.properties.keywords = "GDD, Godot, 逆岁四契, 中国神话, 游戏策划"
    wb.properties.description = (
        "由现有GDD v1.6、implementation-status.md与2026-10-27确认的"
        "五室关卡/岁髓岁灯/主动技能方案整理。"
    )
    wb.calculation.fullCalcOnLoad = True
    wb.calculation.forceFullCalc = True

    for ws in wb.worksheets:
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.print_title_rows = "1:2"
        ws.oddFooter.center.text = "《逆岁：四契》v1.7｜内部策划与制作台账"
        ws.oddFooter.center.size = 8
        ws.oddFooter.center.color = COLORS["gray"]


def build_workbook() -> Path:
    wb = Workbook()
    add_cover(wb)
    add_decisions_sheet(wb)
    add_overview_sheet(wb)
    add_loop_sheet(wb)
    add_narrative_sheet(wb)
    add_room_sheet(wb)
    add_enemy_sheet(wb)
    add_marrow_sheet(wb)
    add_skill_sheet(wb)
    add_boss_sheet(wb)
    add_mask_sheet(wb)
    add_combat_sheet(wb)
    add_ui_save_sheet(wb)
    add_art_audio_sheet(wb)
    add_tech_sheet(wb)
    add_production_sheet(wb)
    add_risk_sheet(wb)
    add_daily_sheet(wb)
    finalize_workbook(wb)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    wb.save(OUTPUT)
    return OUTPUT


def validate_workbook(path: Path) -> None:
    wb = load_workbook(path, read_only=False, data_only=False)
    expected = [
        "00_封面与索引",
        "01_当前决议",
        "02_项目概览",
        "03_核心循环",
        "04_世界观叙事",
        "05_五室关卡",
        "06_敌兵与小Boss",
        "07_岁髓与岁灯",
        "08_主动技能",
        "09_四象Boss",
        "10_面具系统",
        "11_战斗手感",
        "12_UI剧情存档",
        "13_美术音频",
        "14_技术架构",
        "15_生产验收",
        "16_风险待决",
        "17_每日更新",
    ]
    if wb.sheetnames != expected:
        raise RuntimeError(f"工作表顺序不符合预期: {wb.sheetnames}")
    if wb["17_每日更新"].max_row < 30:
        raise RuntimeError("每日更新表记录数量不足")
    if wb["08_主动技能"]["A5"].value != "回锋":
        raise RuntimeError("主动技能表内容缺失")
    if wb["05_五室关卡"].max_row < 24:
        raise RuntimeError("五室关卡表内容不足")
    print(f"validated={path}")
    print(f"sheets={len(wb.sheetnames)}")
    print(f"daily_rows={wb['17_每日更新'].max_row - 4}")
    print(f"size={path.stat().st_size}")


if __name__ == "__main__":
    output = build_workbook()
    validate_workbook(output)
