# 07. 参考文档

本目录包含SCI2项目的详细技术参考文档，提供API、数据库和配置等方面的详细说明。

## 目录结构

- **api/** - API参考文档
- **database/** - 数据库参考文档
- **configuration/** - 配置参考文档

## 适用人群

- 开发人员
- 系统管理员
- 技术支持人员
- API集成开发人员

## API参考

目前API参考文档正在完善中，将包含：
- RESTful API接口说明
- 数据格式和响应结构
- 认证和授权机制
- 错误代码和处理

## 数据库参考

### SQLite优化文档
- [SQLite导入优化计划](database/SQLite导入优化计划.md) - SQLite数据库导入性能优化方案
- [SQLite优化评估与实施](database/SQLite优化评估与实施.md) - SQLite数据库优化评估和实施计划
- [SQLite优化第一阶段实施总结](database/SQLite优化第一阶段实施总结.md) - 第一阶段优化实施结果总结
- [SQLite优化第二阶段实施总结](database/SQLite优化第二阶段实施总结.md) - 第二阶段优化实施结果总结
- [SQLite配置优化计划](database/SQLite配置优化计划.md) - SQLite数据库配置优化方案

### 其他数据库优化
- [Excel_SQLite导入优化计划](database/Excel_SQLite导入优化计划.md) - Excel数据导入SQLite的优化方案
- [Rails_SQLite导入优化计划](database/Rails_SQLite导入优化计划.md) - Rails框架下SQLite导入优化方案

### 数据库设计
- [数据库结构调整](../02-architecture/database/数据库结构调整.md) - 数据库结构设计和调整说明

## 配置参考

### 系统配置
- [费用明细重复修复文件索引](configuration/费用明细重复修复文件索引.md) - 相关配置文件索引和说明

### 配置文件结构
- 数据库配置 (config/database.yml)
- 应用配置 (config/application.rb)
- 环境配置 (config/environments/*.rb)
- 部署配置 (config/deploy/*.rb)

## 性能优化参考

### 数据库优化
- 查询优化技巧
- 索引设计原则
- 批量操作优化
- 连接池配置

### 应用优化
- 代码级优化策略
- 内存使用优化
- 缓存机制配置
- 并发处理优化

### 导入优化
- CSV导入优化
- 大文件处理策略
- 错误处理机制
- 进度跟踪实现

## 参考文档使用指南

1. **按需查阅** - 根据具体需求查阅相关章节
2. **结合实践** - 将参考文档与实际开发结合使用
3. **保持更新** - 注意文档版本与系统版本的对应关系
4. **反馈建议** - 对文档内容提出改进建议

## 相关文档

- [系统架构](../02-architecture/) - 系统设计文档
- [开发指南](../03-development/) - 开发实现指南
- [运维指南](../05-operations/) - 运维操作文档