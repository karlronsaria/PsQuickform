class ProgressWriter {
    [Int] $Id
    [Int] $Current
    [Int] $Count
    [String] $Activity

    [Double] GetProgress() {
        return $this.Current / $this.Count
    }

    [Bool] Any() {
        return $this.GetProgress() -lt 1
    }

    static hidden [Int]
    RunNextProgressWrite(
        [Int] $Id,
        [Int] $Current,
        [Int] $Count,
        [String] $Activity,
        [ScriptBlock] $Status
    ) {
        $progress = $Current / $Count
        $statusLine = & $Status

        if ([String]::IsNullOrWhiteSpace($statusLine)) {
            Write-Progress `
                -Id $Id `
                -Activity $Activity `
                -PercentComplete (100 * $progress)
        }
        else {
            Write-Progress `
                -Id $Id `
                -Activity $Activity `
                -Status $statusLine.ToString() `
                -PercentComplete (100 * $progress)
        }

        return $Current + 1
    }

    hidden [ScriptBlock] $NextBlock__

    [void] Init(
        [Int] $Id,
        [Int] $Current,
        [Int] $Count,
        [String] $Activity
    ) {
        $this.Id = $Id
        $this.Current = $Current
        $this.Count = $Count
        $this.Activity = $Activity

        $this.NextBlock__ = {
            Param(
                [ProgressWriter]
                $ProgressWriter,

                [ScriptBlock]
                $Status
            )

            $ProgressWriter.Current =
                [ProgressWriter]::RunNextProgressWrite(
                    $ProgressWriter.Id,
                    $ProgressWriter.Current,
                    $ProgressWriter.Count,
                    $ProgressWriter.Activity,
                    $Status
                )

            return $ProgressWriter.Any()
        }
    }

    ProgressWriter(
        [Int] $Id,
        [Int] $Start,
        [Int] $Count,
        [String] $Activity
    ) {
        $this.Init($Id, $Start, $Count, $Activity)
    }

    [Bool] Next([ScriptBlock] $Status) {
        return & $this.NextBlock__ `
            -ProgressWriter $this `
            -Status $Status
    }

    [Bool] Complete() {
        Write-Progress `
            -Id $this.Id `
            -Activity $this.Activity `
            -Complete

        $this.NextBlock__ = {
            Param(
                [ProgressWriter]
                $ProgressWriter,

                [ScriptBlock]
                $Status
            )

            return $false
        }

        return $this.Any()
    }
}

