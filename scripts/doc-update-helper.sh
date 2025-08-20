#!/bin/bash

# SCI2 文档更新助手脚本
# 用于帮助开发人员快速找到并更新相关文档

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "SCI2 文档更新助手"
    echo ""
    echo "用法: $0 [选项] [变更类型] [关键词]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -l, --list          列出所有文档类型"
    echo "  -f, --find          查找包含关键词的文档"
    echo "  -c, --check         检查文档一致性"
    echo "  -u, --update        更新文档向导"
    echo ""
    echo "变更类型:"
    echo "  feature             功能变更"
    echo "  database            数据库变更"
    echo "  api                 API变更"
    echo "  config              配置变更"
    echo "  performance         性能优化"
    echo "  deployment          部署相关"
    echo ""
    echo "示例:"
    echo "  $0 -u feature 报销"
    echo "  $0 -f 数据库"
    echo "  $0 -c"
}

# 列出所有文档类型
list_docs() {
    print_info "文档结构列表："
    echo ""
    echo "📁 01-getting-started/     - 快速入门"
    echo "  ├── overview/            - 项目概览"
    echo "  ├── quick-start/         - 快速开始"
    echo "  └── installation/        - 安装配置"
    echo ""
    echo "📁 02-architecture/        - 系统架构"
    echo "  ├── system-design/       - 系统设计"
    echo "  ├── database/           - 数据库设计"
    echo "  └── api/                - API设计"
    echo ""
    echo "📁 03-development/        - 开发指南"
    echo "  ├── feature-development/ - 功能开发"
    echo "  ├── testing/            - 测试规范"
    echo "  └── coding-standards/   - 编码标准"
    echo ""
    echo "📁 04-deployment/         - 部署指南"
    echo "  ├── production/         - 生产环境"
    echo "  ├── staging/            - 测试环境"
    echo "  └── development/        - 开发环境"
    echo ""
    echo "📁 05-operations/         - 运维指南"
    echo "  ├── monitoring/         - 系统监控"
    echo "  ├── maintenance/        - 系统维护"
    echo "  └── troubleshooting/     - 故障排除"
    echo ""
    echo "📁 06-ai-development/     - AI开发支持"
    echo "  ├── prompts/            - 提示词模板"
    echo "  ├── templates/          - 代码模板"
    echo "  └── examples/           - 示例代码"
    echo ""
    echo "📁 07-reference/          - 参考文档"
    echo "  ├── api/                - API参考"
    echo "  ├── database/           - 数据库参考"
    echo "  └── configuration/      - 配置参考"
    echo ""
    echo "📁 08-migration/          - 迁移计划"
    echo "  ├── plans/              - 迁移计划"
    echo "  ├── scripts/            - 迁移脚本"
    echo "  └── backup/             - 备份恢复"
    echo ""
    echo "📁 09-archive/            - 归档文档"
    echo "  ├── legacy/             - 历史版本"
    echo "  ├── deprecated/         - 废弃功能"
    echo "  └── backup/             - 备份文档"
}

# 查找包含关键词的文档
find_docs() {
    local keyword="$1"
    if [ -z "$keyword" ]; then
        print_error "请提供搜索关键词"
        return 1
    fi
    
    print_info "搜索包含 '$keyword' 的文档..."
    echo ""
    
    # 搜索文档文件
    local results=$(find docs/ -name "*.md" -type f -exec grep -l "$keyword" {} \; 2>/dev/null | sort)
    
    if [ -z "$results" ]; then
        print_warning "未找到包含 '$keyword' 的文档"
        return 1
    fi
    
    echo "找到以下相关文档："
    echo ""
    echo "$results" | while read -r file; do
        echo "📄 $file"
        # 显示包含关键词的行数
        local count=$(grep -c "$keyword" "$file" 2>/dev/null || echo 0)
        echo "   匹配行数: $count"
        echo ""
    done
}

# 检查文档一致性
check_consistency() {
    print_info "检查文档一致性..."
    echo ""
    
    # 检查1: 验证所有README文件存在
    print_info "检查README文件..."
    local readme_count=$(find docs/ -name "README.md" | wc -l)
    echo "README文件数量: $readme_count"
    
    # 检查2: 验证文档链接
    print_info "检查文档链接..."
    local broken_links=$(find docs/ -name "*.md" -exec grep -l "\[.*\](.*\.md)" {} \; | wc -l)
    echo "包含链接的文档: $broken_links"
    
    # 检查3: 检查最近更新的文档
    print_info "检查最近更新的文档..."
    echo "最近7天更新的文档："
    find docs/ -name "*.md" -mtime -7 -exec ls -la {} \;
    
    # 检查4: 检查文档大小异常
    print_info "检查文档大小..."
    echo "可能需要关注的文档（小于100字节或大于100KB）："
    find docs/ -name "*.md" -size -100c -o -size +100k | head -10
    
    print_success "一致性检查完成"
}

# 更新文档向导
update_docs() {
    local change_type="$1"
    local keyword="$2"
    
    if [ -z "$change_type" ]; then
        print_error "请指定变更类型"
        echo "支持的变更类型: feature, database, api, config, performance, deployment"
        return 1
    fi
    
    print_info "开始文档更新向导..."
    print_info "变更类型: $change_type"
    [ -n "$keyword" ] && print_info "关键词: $keyword"
    echo ""
    
    # 根据变更类型确定文档位置
    case $change_type in
        "feature")
            print_info "功能变更 - 需要更新的文档："
            echo "📁 docs/03-development/feature-development/"
            echo "📁 docs/02-architecture/system-design/"
            echo "📁 docs/03-development/testing/"
            ;;
        "database")
            print_info "数据库变更 - 需要更新的文档："
            echo "📁 docs/02-architecture/database/"
            echo "📁 docs/07-reference/database/"
            echo "📁 docs/08-migration/plans/"
            ;;
        "api")
            print_info "API变更 - 需要更新的文档："
            echo "📁 docs/02-architecture/api/"
            echo "📁 docs/07-reference/api/"
            echo "📁 docs/03-development/feature-development/"
            ;;
        "config")
            print_info "配置变更 - 需要更新的文档："
            echo "📁 docs/07-reference/configuration/"
            echo "📁 docs/04-deployment/"
            ;;
        "performance")
            print_info "性能优化 - 需要更新的文档："
            echo "📁 docs/07-reference/database/"
            echo "📁 docs/03-development/coding-standards/"
            echo "📁 docs/05-operations/monitoring/"
            ;;
        "deployment")
            print_info "部署相关 - 需要更新的文档："
            echo "📁 docs/04-deployment/"
            echo "📁 docs/05-operations/maintenance/"
            ;;
        *)
            print_error "不支持的变更类型: $change_type"
            return 1
            ;;
    esac
    
    echo ""
    
    # 如果有关键词，搜索相关文档
    if [ -n "$keyword" ]; then
        print_info "搜索包含 '$keyword' 的相关文档..."
        find_docs "$keyword"
    fi
    
    echo ""
    print_info "更新步骤："
    echo "1. 查看上述列出的文档目录"
    echo "2. 找到需要更新的具体文档"
    echo "3. 按照文档格式更新内容"
    echo "4. 检查关联文档是否需要更新"
    echo "5. 验证更新后的文档内容"
    echo ""
    print_info "更新模板："
    echo "## 更新记录"
    echo "### $(date +%Y-%m-%d) 更新"
    echo "**变更内容**: [描述您的变更]"
    echo "**影响范围**: [说明影响的功能或模块]"
    echo "**相关代码**: [涉及的文件或类名]"
    echo "**操作说明**: [具体的操作步骤]"
    echo ""
    print_success "向导完成！请按照上述步骤更新文档"
}

# 主函数
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -l|--list)
            list_docs
            ;;
        -f|--find)
            find_docs "$2"
            ;;
        -c|--check)
            check_consistency
            ;;
        -u|--update)
            update_docs "$2" "$3"
            ;;
        "")
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"