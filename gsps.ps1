param(
    [Parameter(Mandatory=$true)]
    [string]$PackageName
)

function Get-ScoopPackageSize {
    try {
        
        # 使用 scoop cat 获取包的 JSON 内容
        $jsonText = scoop cat $PackageName 2>$null
        if (-not $jsonText) {
            Write-Host "错误: 找不到包 $PackageName" -ForegroundColor Red
            return
        }
        
        # 解析 JSON
        $packageInfo = $jsonText | ConvertFrom-Json
        
        # 获取下载链接（优先 64位，然后 32位，最后顶级 URL）
        $architecture = $null
        $url = $null
        if ($packageInfo.architecture -and $packageInfo.architecture.'64bit' -and $packageInfo.architecture.'64bit'.url) {
            $url = $packageInfo.architecture.'64bit'.url
            $architecture = "64bit"
        }
        elseif ($packageInfo.architecture -and $packageInfo.architecture.'32bit' -and $packageInfo.architecture.'32bit'.url) {
            $url = $packageInfo.architecture.'32bit'.url
            $architecture = "32bit"
        }
        elseif ($packageInfo.url) {
            $url = $packageInfo.url
            $architecture = "顶级"
        }
        
        if (-not $url) {
            Write-Host "错误: 无法从 JSON 中提取下载链接" -ForegroundColor Red
            return
        }
        
        # 清理 URL（移除 #/dl.7z 等后缀）
        $cleanUrl = $url -replace '#.*$', ''
        Write-Host "找到 " -NoNewline
        Write-Host "$architecture " -ForegroundColor Yellow -NoNewline
        Write-Host "下载链接"
        # Write-Host "$cleanUrl" -ForegroundColor Cyan
        Write-Host ""
        
        # 获取文件大小
        
        try {
            # 发送 HEAD 请求
            $request = [System.Net.HttpWebRequest]::Create($cleanUrl)
            $request.Method = "HEAD"
            $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            $request.AllowAutoRedirect = $true
            
            $response = $request.GetResponse()
            $contentLength = $response.Headers["Content-Length"]
            $response.Close()
            
            if ($contentLength) {
                $bytes = [long]$contentLength
                $mb = [math]::Round($bytes / 1MB, 2)
                $gb = [math]::Round($bytes / 1GB, 2)
                
                Write-Host "name: " -ForegroundColor Yellow -NoNewline
                Write-Host $PackageName -ForegroundColor Cyan
                
                Write-Host "size: " -ForegroundColor Yellow -NoNewline
                if ($gb -gt 1) {
                    Write-Host "$gb GB" -ForegroundColor Cyan
                }
                else {
                    Write-Host "$mb MB" -ForegroundColor Cyan
                }
            }
            else {
                Write-Host "错误: 无法获取 Content-Length" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "错误: 无法获取文件大小 - $_" -ForegroundColor Red
            
            # 备用方案：使用 curl
            Write-Host "尝试使用 curl 获取..." -ForegroundColor Yellow
            $curlResult = curl -sIL $cleanUrl 2>$null | Select-String "Content-Length"
            if ($curlResult) {
                $curlResult -match '\d+' | Out-Null
                $bytes = [long]$Matches[0]
                $mb = [math]::Round($bytes / 1MB, 2)
                Write-Host "大小: $mb MB (通过 curl 获取)" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "错误: $_" -ForegroundColor Red
    }
}

# 执行主函数
Get-ScoopPackageSize -PackageName $PackageName
