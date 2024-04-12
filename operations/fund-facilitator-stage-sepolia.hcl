job "fund-facilitator-stage-sepolia" {
    datacenters = ["ator-fin"]
    type = "batch"

    reschedule {
        attempts = 0
    }

    task "fund-facilitator-stage-task" {
        driver = "docker"

        config {
            network_mode = "host"
            image = "ghcr.io/ator-development/ator-token:1.1.17"
            entrypoint = ["npx"]
            command = "hardhat"
            args = ["run", "--network", "sepolia", "scripts/fund-facilitator.ts"]
        }

        vault {
            policies = ["ator-token-sepolia-stage"]
        }

        template {
            data = <<EOH
            {{with secret "kv/ator-token/sepolia/stage"}}
                TOKEN_DEPLOYER_KEY="{{.Data.data.TOKEN_DEPLOYER_KEY}}"
                JSON_RPC="{{.Data.data.JSON_RPC}}"
            {{end}}
            EOH
            destination = "secrets/file.env"
            env         = true
        }

        env {
            PHASE="stage"
            CONSUL_IP="127.0.0.1"
            CONSUL_PORT="8500"
            TOKEN_CONSUL_KEY="ator-token/sepolia/stage/address"
            FACILITATOR_CONSUL_KEY="facilitator/sepolia/stage/address"
            FUND_VALUE="1000"
        }

        restart {
            attempts = 0
            mode = "fail"
        }

        resources {
            cpu    = 4096
            memory = 4096
        }
    }
}
