local TableView      	= import("app.components.TableViewEx")
local GridView 			= class("GridView", cc.Node)

--[[
	/*	@context
	 *		viewSize GridView的最终大小 一般是 width = (列数 + 列间隔) * 列大小 - 列间隔 height = (行数 + 行间隔) * 行数 - 行间隔 
	 *		cellSize 单个元素大小
	 *		direction 滚动方向
	 *		rowCount 每一列有多少行   水平滑动使用
	 *		fieldCount 每一行有多少列 垂直滑动使用
	 *		VGAP 水平间距
	 *		HGAP 垂直间距
	 *		debugDraw 调试模式
	 */

]]
function GridView:ctor(context)
	self.context = {
		viewSize 	= context.viewSize 		or { width = 327, height = 327 },
		cellSize 	= context.cellSize 		or { width = 30,  height = 30 },
		direction 	= context.direction 	or cc.SCROLLVIEW_DIRECTION_VERTICAL,
		rowCount 	= context.rowCount 		or 1,
		fieldCount	= context.fieldCount 	or 1,
		VGAP 		= context.VGAP 			or 0,
		HGAP		= context.HGAP 			or 0,
		debugDraw	= context.debugDraw
	}
	self.datas = {}
	self.m_CellPool = {}
	self:setContentSize(self.context.viewSize.width, self.context.viewSize.height)
	self:setAnchorPoint(0.5, 0.5)

	if self.context.debugDraw then
		self:debugDraw(self)
	end
	self:onNodeEvent("cleanup", function() self:cleanupBeforeDelete() end)
	self:onCreate()
end

--初始化 计算出一部分需要用到的东西
function GridView:onCreate()
	--TODO
	--Create TableVIew
    self.tableView = TableView:create({
                size = self.context.viewSize,
                cellSize = function(_, idx) return self:getBigCellSizeAtIndex(idx) end,
                direction = self.context.direction,
            })
        :onCellAtIndex(handler(self, self.showCell))
        :addTo(self)

	self.isVertical = self.context.direction == cc.SCROLLVIEW_DIRECTION_VERTICAL
    local context = self.context
	self.maxLineCount = context.direction == cc.SCROLLVIEW_DIRECTION_VERTICAL and context.fieldCount or context.rowCount
	local cellSize = context.cellSize
	self.normalSize = {
		width = self.isVertical and (cellSize.width + context.VGAP) * self.maxLineCount or cellSize.width + context.HGAP,
		height = self.isVertical and cellSize.height + context.VGAP or (cellSize.height + context.VGAP) * self.maxLineCount
	}
	self.topSize = {
			width = self.normalSize.width,
			height = self.normalSize.height - context.VGAP,
		}
	self.bottomSize = {
			width = self.normalSize.width - context.HGAP,
			height = self.normalSize.height,
		}
end

--内存泄露检测
function GridView:cleanupBeforeDelete()
	for k, v in pairs(self.m_CellPool) do
		if v:getReferenceCount() > 1 then
			print("警告: 在GridView销毁时检测到引用次数大于1的Cell 清注意调用release() 防止内存泄露！")
		end
		v:release()
	end
end

--获取Cell
function GridView:dequeueCell(parent)
	local cell = nil
	if #self.m_CellPool == 0 then
		cell = cc.Node:create()
					  :addTo(parent)
					  :setContentSize(self.context.cellSize.width, self.context.cellSize.height)
					  :setAnchorPoint(0, 0)
		if self.context.debugDraw then
			self:debugDraw(cell, cc.c4f(math.random(1, 100) / 100, math.random(1, 100) / 100, math.random(1, 100) / 100, 1))
		end
	else
		cell = table.remove(self.m_CellPool, 1):addTo(parent):release():show()
	end
	return cell
end

--回收Cell
function GridView:ququqCell(cell)
	table.insert(self.m_CellPool, cell)
	cell:retain()
		:removeFromParent()
		:hide()
end

--刷新数据
function GridView:setDatas(datas)
	self.datas = datas or {}
	self.tableView:setNumbers(math.ceil(#self.datas / self.maxLineCount))
	self.tableView:reloadData()
end

--获取TableViewCell大小
function GridView:getBigCellSizeAtIndex(index)
	if self.isVertical and index == 0 then
		return self.topSize
	elseif not self.isVertical and index == math.ceil(#self.datas / self.maxLineCount) - 1 then
		return self.bottomSize
	end
	return self.normalSize
end

--刷新
function GridView:showCell(cell,idx)
	local context = self.context
	cell.__items = cell.__items or {}
	local size = self:getBigCellSizeAtIndex(idx)
	cell:setContentSize(size.width, size.height)
	if context.debugDraw then
		self:debugDraw(cell, cc.c4f(math.random(1, 100) / 100, math.random(1, 100) / 100, math.random(1, 100) / 100, 1))
	end
	local maxLineCount = self.maxLineCount
	local startPos = idx * maxLineCount
	local tempMaxLineCount = maxLineCount - 1
	maxLineCount = maxLineCount - 1
	while maxLineCount >= 0 do
		local currIndex = startPos + maxLineCount + 1
		if currIndex > #self.datas then
			if cell.__items[maxLineCount] then self:ququqCell(table.remove(cell.__items, maxLineCount)) end
		else
			local currCell = cell.__items[maxLineCount] or self:dequeueCell(cell)
			currCell.getIndex = function() return currIndex end
			cell.__items[maxLineCount] = currCell
			local currPosX = self.isVertical and (maxLineCount * (context.cellSize.width + context.HGAP)) or 0
			local currPosY = not self.isVertical and ((tempMaxLineCount - maxLineCount) * (context.cellSize.height + context.VGAP)) or 0
			currCell:move(currPosX, currPosY)

			if self.onCellAtIndex then self.onCellAtIndex(currCell, self.datas[currIndex]) end
		end	
		maxLineCount = maxLineCount - 1
	end
end

--调试用 画出元素位置
function GridView:debugDraw(parent, color, size)
	if parent.__drawNode then parent.__drawNode:removeFromParent() end
	local myDrawNode=cc.DrawNode:create()
    parent:addChild(myDrawNode)
    myDrawNode:setPosition(0, 0)
    size = size or cc.p(parent:getContentSize().width, parent:getContentSize().height)
    myDrawNode:drawSolidRect(cc.p(0, 0), size, color or cc.c4f(1,1,1,1))
    myDrawNode:setLocalZOrder(-10)
    parent.__drawNode = myDrawNode
end

return GridView