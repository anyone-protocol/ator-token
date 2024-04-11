job "ator-token-deploy-dev-sepolia" {
    datacenters = ["ator-fin"]
    type = "batch"

    reschedule {
        attempts = 0
    }

    task "deploy-ator-token-dev-task" {
        driver = "docker"

        config {
            network_mode = "host"
            image = "ghcr.io/ator-development/ator-token:1.1.15"
            entrypoint = ["npx"]
            command = "hardhat"
            args = ["run", "--network", "sepolia", "scripts/deploy.ts"]
        }

        vault {
            policies = ["ator-token-sepolia-dev"]
        }

        template {
            data = <<EOH
            {{with secret "kv/ator-token/sepolia/dev"}}
                TOKEN_DEPLOYER_KEY="{{.Data.data.TOKEN_DEPLOYER_KEY}}"
                CONSUL_TOKEN="{{.Data.data.CONSUL_TOKEN}}"
                JSON_RPC="{{.Data.data.JSON_RPC}}"
            {{end}}
            EOH
            destination = "secrets/file.env"
            env         = true
        }

        env {
            PHASE="dev"
            CONSUL_IP="127.0.0.1"
            CONSUL_PORT="8500"
            CONSUL_KEY="ator-token/sepolia/dev/address"
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
