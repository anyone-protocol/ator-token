job "ator-token-deploy-goerli" {
    datacenters = ["ator-fin"]
    type = "batch"

    reschedule {
        attempts = 0
    }

    task "deploy-ator-token-task" {
        driver = "docker"

        config {
            network_mode = "host"
            image = "ghcr.io/ator-development/ator-token:1.1.8"
            entrypoint = ["npx"]
            command = "hardhat"
            args = ["run", "--network", "goerli", "scripts/deploy.ts"]
        }

        vault {
            policies = ["ator-goerli"]
        }

        template {
            data = <<EOH
            {{with secret "kv/ator-goerli"}}
                DEPLOYER_PRIVATE_KEY="{{.Data.data.OWNER_KEY}}"
                CONSUL_TOKEN="{{.Data.data.CONSUL_TOKEN}}"
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
            CONSUL_KEY="ator-goerli/address"
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
